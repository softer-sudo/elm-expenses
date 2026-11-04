module ExpenseTest exposing (suite)

import Expect
import Expense exposing (Category(..), Expense)
import Json.Decode as Decode
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Expense"
        [ describe "decoder"
            [ test "decodes a valid list" <|
                \_ ->
                    Decode.decodeString Expense.listDecoder
                        """[{"id":1,"title":"Rent","amountCents":90000,"category":"housing"}]"""
                        |> Expect.equal (Ok [ Expense 1 "Rent" 90000 Housing ])
            , test "rejects an unknown category" <|
                \_ ->
                    Decode.decodeString Expense.decoder
                        """{"id":1,"title":"x","amountCents":1,"category":"crypto"}"""
                        |> Expect.err
            , test "rejects a missing field" <|
                \_ ->
                    Decode.decodeString Expense.decoder """{"id":1,"title":"x","category":"fun"}"""
                        |> Expect.err
            , test "rejects a fractional amountCents" <|
                \_ ->
                    Decode.decodeString Expense.decoder
                        """{"id":1,"title":"x","amountCents":1.5,"category":"fun"}"""
                        |> Expect.err
            ]
        , describe "parseAmount"
            [ test "parses decimals into cents" <|
                \_ -> Expense.parseAmount " 12.5 " |> Expect.equal (Ok 1250)
            , test "rounds float noise" <|
                \_ -> Expense.parseAmount "0.1" |> Expect.equal (Ok 10)
            , test "rejects text" <|
                \_ -> Expense.parseAmount "abc" |> Expect.err
            , test "rejects zero, negatives and sub-cent values" <|
                \_ ->
                    List.map Expense.parseAmount [ "0", "-3", "0.001" ]
                        |> List.all (\r -> r == Err "Amount must be positive")
                        |> Expect.equal True
            ]
        , test "formatCents pads cents" <|
            \_ -> List.map Expense.formatCents [ 1250, 5, 0 ] |> Expect.equal [ "12.50", "0.05", "0.00" ]
        , test "totalsByCategory sums per category and skips empty ones" <|
            \_ ->
                Expense.totalsByCategory
                    [ Expense 1 "a" 100 Food, Expense 2 "b" 250 Food, Expense 3 "c" 700 Fun ]
                    |> Expect.equal [ ( Food, 350 ), ( Fun, 700 ) ]
        ]
