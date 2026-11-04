module Main exposing
    ( Form
    , Mode(..)
    , Model
    , Msg(..)
    , RemoteData(..)
    , emptyForm
    , init
    , main
    , update
    , view
    , visibleExpenses
    )

import Browser
import Expense exposing (Category(..), Expense)
import Html exposing (Html, button, form, h1, h2, input, label, li, option, p, section, select, table, tbody, td, text, th, thead, tr, ul)
import Html.Attributes exposing (attribute, placeholder, selected, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http



-- MODEL


type RemoteData e a
    = Loading
    | Failure e
    | Success a


type Mode
    = Adding
    | Editing Int


type alias Form =
    { title : String
    , amount : String
    , category : Category
    , error : Maybe String
    }


type alias Model =
    { expenses : RemoteData Http.Error (List Expense)
    , filter : Maybe Category
    , mode : Mode
    , form : Form
    }


emptyForm : Form
emptyForm =
    { title = "", amount = "", category = Food, error = Nothing }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { expenses = Loading, filter = Nothing, mode = Adding, form = emptyForm }
    , fetchExpenses
    )


fetchExpenses : Cmd Msg
fetchExpenses =
    Http.get { url = "expenses.json", expect = Http.expectJson GotExpenses Expense.listDecoder }



-- UPDATE


type Msg
    = GotExpenses (Result Http.Error (List Expense))
    | Retry
    | SetTitle String
    | SetAmount String
    | SetCategory String
    | Submit
    | StartEdit Int
    | CancelEdit
    | Delete Int
    | SetFilter (Maybe Category)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotExpenses (Ok expenses) ->
            ( { model | expenses = Success expenses }, Cmd.none )

        GotExpenses (Err err) ->
            ( { model | expenses = Failure err }, Cmd.none )

        Retry ->
            ( { model | expenses = Loading }, fetchExpenses )

        SetTitle title ->
            ( updateForm (\f -> { f | title = title }) model, Cmd.none )

        SetAmount amount ->
            ( updateForm (\f -> { f | amount = amount }) model, Cmd.none )

        SetCategory s ->
            ( updateForm (\f -> { f | category = Expense.categoryFromString s |> Maybe.withDefault f.category }) model
            , Cmd.none
            )

        Submit ->
            case ( model.expenses, validate model.form ) of
                ( Success expenses, Ok ( title, cents ) ) ->
                    ( { model
                        | expenses = Success (save model.mode title cents model.form.category expenses)
                        , mode = Adding
                        , form = emptyForm
                      }
                    , Cmd.none
                    )

                ( Success _, Err error ) ->
                    ( updateForm (\f -> { f | error = Just error }) model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        StartEdit id ->
            case model.expenses of
                Success expenses ->
                    case List.filter (\e -> e.id == id) expenses of
                        e :: _ ->
                            ( { model
                                | mode = Editing id
                                , form = { title = e.title, amount = Expense.formatCents e.amountCents, category = e.category, error = Nothing }
                              }
                            , Cmd.none
                            )

                        [] ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        CancelEdit ->
            ( { model | mode = Adding, form = emptyForm }, Cmd.none )

        Delete id ->
            let
                resetIfEditing m =
                    if m.mode == Editing id then
                        { m | mode = Adding, form = emptyForm }

                    else
                        m
            in
            ( resetIfEditing { model | expenses = mapSuccess (List.filter (\e -> e.id /= id)) model.expenses }
            , Cmd.none
            )

        SetFilter filter ->
            ( { model | filter = filter }, Cmd.none )


updateForm : (Form -> Form) -> Model -> Model
updateForm f model =
    { model | form = f model.form }


mapSuccess : (a -> a) -> RemoteData e a -> RemoteData e a
mapSuccess f data =
    case data of
        Success a ->
            Success (f a)

        other ->
            other


validate : Form -> Result String ( String, Int )
validate f =
    let
        title =
            String.trim f.title
    in
    if String.isEmpty title then
        Err "Title is required"

    else
        Expense.parseAmount f.amount |> Result.map (Tuple.pair title)


save : Mode -> String -> Int -> Category -> List Expense -> List Expense
save mode title cents category expenses =
    case mode of
        Adding ->
            let
                nextId =
                    (expenses |> List.map .id |> List.maximum |> Maybe.withDefault 0) + 1
            in
            expenses ++ [ Expense nextId title cents category ]

        Editing id ->
            List.map
                (\e ->
                    if e.id == id then
                        Expense id title cents category

                    else
                        e
                )
                expenses


visibleExpenses : Maybe Category -> List Expense -> List Expense
visibleExpenses filter expenses =
    case filter of
        Nothing ->
            expenses

        Just c ->
            List.filter (\e -> e.category == c) expenses



-- VIEW


view : Model -> Html Msg
view model =
    Html.main_ []
        (h1 [] [ text "Expenses" ]
            :: (case model.expenses of
                    Loading ->
                        [ p [ attribute "role" "status" ] [ text "Loading…" ] ]

                    Failure err ->
                        [ p [ attribute "role" "alert" ] [ text ("Could not load expenses: " ++ httpErrorToString err) ]
                        , button [ onClick Retry ] [ text "Retry" ]
                        ]

                    Success expenses ->
                        [ viewForm model.mode model.form
                        , viewFilter model.filter
                        , viewList (visibleExpenses model.filter expenses)
                        , viewTotals expenses
                        ]
               )
        )


viewForm : Mode -> Form -> Html Msg
viewForm mode f =
    form [ onSubmit Submit ]
        [ h2 []
            [ text
                (case mode of
                    Adding ->
                        "Add expense"

                    Editing _ ->
                        "Edit expense"
                )
            ]
        , label [] [ text "Title ", input [ value f.title, onInput SetTitle, placeholder "Coffee" ] [] ]
        , label [] [ text "Amount ", input [ value f.amount, onInput SetAmount, placeholder "4.50", attribute "inputmode" "decimal" ] [] ]
        , label []
            [ text "Category "
            , select [ onInput SetCategory ]
                (List.map
                    (\c ->
                        option [ value (Expense.categoryToString c), selected (c == f.category) ]
                            [ text (Expense.categoryToString c) ]
                    )
                    Expense.allCategories
                )
            ]
        , button [ type_ "submit" ] [ text "Save" ]
        , case mode of
            Adding ->
                text ""

            Editing _ ->
                button [ type_ "button", onClick CancelEdit ] [ text "Cancel" ]
        , case f.error of
            Just error ->
                p [ attribute "role" "alert" ] [ text error ]

            Nothing ->
                text ""
        ]


viewFilter : Maybe Category -> Html Msg
viewFilter current =
    let
        filterButton name filter =
            button
                [ onClick (SetFilter filter)
                , attribute "aria-pressed"
                    (if filter == current then
                        "true"

                     else
                        "false"
                    )
                ]
                [ text name ]
    in
    section [ attribute "aria-label" "Filter" ]
        (filterButton "all" Nothing
            :: List.map (\c -> filterButton (Expense.categoryToString c) (Just c)) Expense.allCategories
        )


viewList : List Expense -> Html Msg
viewList expenses =
    if List.isEmpty expenses then
        p [] [ text "No expenses." ]

    else
        ul []
            (List.map
                (\e ->
                    li []
                        [ text (e.title ++ " · " ++ Expense.categoryToString e.category ++ " · " ++ Expense.formatCents e.amountCents ++ " ")
                        , button [ onClick (StartEdit e.id) ] [ text "Edit" ]
                        , button [ onClick (Delete e.id) ] [ text "Delete" ]
                        ]
                )
                expenses
            )


viewTotals : List Expense -> Html Msg
viewTotals expenses =
    section []
        [ h2 [] [ text "Totals" ]
        , table []
            [ thead [] [ tr [] [ th [] [ text "Category" ], th [] [ text "Total" ] ] ]
            , tbody []
                (List.map
                    (\( c, cents ) -> tr [] [ td [] [ text (Expense.categoryToString c) ], td [] [ text (Expense.formatCents cents) ] ])
                    (Expense.totalsByCategory expenses)
                    ++ [ tr [] [ th [] [ text "All" ], th [] [ text (Expense.formatCents (List.sum (List.map .amountCents expenses))) ] ] ]
                )
            ]
        ]


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        Http.BadUrl url ->
            "bad URL " ++ url

        Http.Timeout ->
            "timeout"

        Http.NetworkError ->
            "network error"

        Http.BadStatus status ->
            "HTTP " ++ String.fromInt status

        Http.BadBody details ->
            "unexpected data: " ++ details



-- MAIN


main : Program () Model Msg
main =
    Browser.element { init = init, update = update, view = view, subscriptions = \_ -> Sub.none }
