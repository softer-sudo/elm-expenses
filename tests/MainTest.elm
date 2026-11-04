module MainTest exposing (suite)

import Expect
import Expense exposing (Category(..), Expense)
import Http
import Main exposing (Mode(..), Model, Msg(..), RemoteData(..))
import Test exposing (Test, describe, test)


loaded : Model
loaded =
    Tuple.first (Main.init ())
        |> run [ GotExpenses (Ok [ Expense 1 "Rent" 90000 Housing, Expense 2 "Coffee" 450 Food ]) ]


run : List Msg -> Model -> Model
run msgs model =
    List.foldl (\msg m -> Tuple.first (Main.update msg m)) model msgs


expensesOf : Model -> List Expense
expensesOf model =
    case model.expenses of
        Success xs ->
            xs

        _ ->
            []


suite : Test
suite =
    describe "update"
        [ test "starts in Loading" <|
            \_ -> (Tuple.first (Main.init ())).expenses |> Expect.equal Loading
        , test "an HTTP error becomes Failure" <|
            \_ ->
                Tuple.first (Main.init ())
                    |> run [ GotExpenses (Err Http.NetworkError) ]
                    |> .expenses
                    |> Expect.equal (Failure Http.NetworkError)
        , test "Retry goes back to Loading" <|
            \_ ->
                Tuple.first (Main.init ())
                    |> run [ GotExpenses (Err Http.Timeout), Retry ]
                    |> .expenses
                    |> Expect.equal Loading
        , test "adds an expense with the next id and resets the form" <|
            \_ ->
                loaded
                    |> run [ SetTitle " Taxi ", SetAmount "12.5", SetCategory "transport", Submit ]
                    |> Expect.all
                        [ expensesOf >> List.reverse >> List.head >> Expect.equal (Just (Expense 3 "Taxi" 1250 Transport))
                        , .form >> Expect.equal Main.emptyForm
                        ]
        , test "invalid input keeps the list and shows an error" <|
            \_ ->
                loaded
                    |> run [ SetTitle "Taxi", SetAmount "lots", Submit ]
                    |> Expect.all
                        [ expensesOf >> List.length >> Expect.equal 2
                        , .form >> .error >> Expect.equal (Just "Amount must be a number")
                        ]
        , test "empty title is rejected" <|
            \_ ->
                loaded
                    |> run [ SetTitle "  ", SetAmount "1", Submit ]
                    |> .form
                    |> .error
                    |> Expect.equal (Just "Title is required")
        , test "Submit before data loads does nothing" <|
            \_ ->
                Tuple.first (Main.init ())
                    |> run [ SetTitle "Taxi", SetAmount "1", Submit ]
                    |> .expenses
                    |> Expect.equal Loading
        , test "edits an expense in place" <|
            \_ ->
                loaded
                    |> run [ StartEdit 2, SetAmount "5", Submit ]
                    |> Expect.all
                        [ expensesOf >> Expect.equal [ Expense 1 "Rent" 90000 Housing, Expense 2 "Coffee" 500 Food ]
                        , .mode >> Expect.equal Adding
                        ]
        , test "StartEdit fills the form" <|
            \_ ->
                loaded
                    |> run [ StartEdit 2 ]
                    |> Expect.all
                        [ .mode >> Expect.equal (Editing 2)
                        , .form >> Expect.equal { title = "Coffee", amount = "4.50", category = Food, error = Nothing }
                        ]
        , test "deletes an expense and leaves edit mode for it" <|
            \_ ->
                loaded
                    |> run [ StartEdit 2, Delete 2 ]
                    |> Expect.all
                        [ expensesOf >> List.map .id >> Expect.equal [ 1 ]
                        , .mode >> Expect.equal Adding
                        ]
        , test "filter shows one category" <|
            \_ ->
                loaded
                    |> run [ SetFilter (Just Food) ]
                    |> (\m -> Main.visibleExpenses m.filter (expensesOf m))
                    |> List.map .title
                    |> Expect.equal [ "Coffee" ]
        ]
