module Expense exposing
    ( Category(..)
    , Expense
    , allCategories
    , categoryFromString
    , categoryToString
    , decoder
    , formatCents
    , listDecoder
    , parseAmount
    , totalsByCategory
    )

import Json.Decode as Decode exposing (Decoder)


type Category
    = Food
    | Transport
    | Housing
    | Fun
    | Other


type alias Expense =
    { id : Int
    , title : String
    , amountCents : Int
    , category : Category
    }


allCategories : List Category
allCategories =
    [ Food, Transport, Housing, Fun, Other ]


categoryToString : Category -> String
categoryToString category =
    case category of
        Food ->
            "food"

        Transport ->
            "transport"

        Housing ->
            "housing"

        Fun ->
            "fun"

        Other ->
            "other"


categoryFromString : String -> Maybe Category
categoryFromString s =
    allCategories
        |> List.filter (\c -> categoryToString c == s)
        |> List.head


categoryDecoder : Decoder Category
categoryDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case categoryFromString s of
                    Just c ->
                        Decode.succeed c

                    Nothing ->
                        Decode.fail ("Unknown category: " ++ s)
            )


decoder : Decoder Expense
decoder =
    Decode.map4 Expense
        (Decode.field "id" Decode.int)
        (Decode.field "title" Decode.string)
        (Decode.field "amountCents" Decode.int)
        (Decode.field "category" categoryDecoder)


listDecoder : Decoder (List Expense)
listDecoder =
    Decode.list decoder


{-| "12.5" -> Ok 1250. Money is kept in integer cents so sums never drift.
-}
parseAmount : String -> Result String Int
parseAmount input =
    case String.toFloat (String.trim input) of
        Nothing ->
            Err "Amount must be a number"

        Just x ->
            if isNaN x || isInfinite x || round (x * 100) <= 0 then
                Err "Amount must be positive"

            else
                Ok (round (x * 100))


formatCents : Int -> String
formatCents cents =
    let
        sign =
            if cents < 0 then
                "-"

            else
                ""

        abs_ =
            abs cents
    in
    sign ++ String.fromInt (abs_ // 100) ++ "." ++ String.padLeft 2 '0' (String.fromInt (modBy 100 abs_))


totalsByCategory : List Expense -> List ( Category, Int )
totalsByCategory expenses =
    allCategories
        |> List.map
            (\c ->
                ( c
                , expenses
                    |> List.filter (\e -> e.category == c)
                    |> List.map .amountCents
                    |> List.sum
                )
            )
        |> List.filter (\( _, total ) -> total > 0)
