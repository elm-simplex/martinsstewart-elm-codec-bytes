module Codec.Bytes exposing
    ( Codec, Endianness, Encoder, Bytes
    , Decoder, decoder, decodeValue
    , encoder, encodeToValue
    , string, bool, char, signedInt, unsignedInt, float64, float32, signedInt32, unsignedInt32, signedInt16, unsignedInt16, signedInt8, unsignedInt8, bytes
    , maybe, list, array, dict, set, tuple, triple, result
    , ObjectCodec, object, field, buildObject
    , CustomCodec, custom, variant0, variant1, variant2, variant3, variant4, variant5, variant6, variant7, variant8, buildCustom
    , map
    , constant, lazy, recursive, customWithIdCodec
    )

{-| A `Codec a` contains a `Bytes.Decoder a` and the corresponding `a -> Bytes.Encoder`.


# Definition

@docs Codec, Endianness, Encoder, Bytes


# Decode

@docs Decoder, decoder, decodeValue


# Encode

@docs encoder, encodeToValue


# Primitives

@docs string, bool, char, signedInt, unsignedInt, float64, float32, signedInt32, unsignedInt32, signedInt16, unsignedInt16, signedInt8, unsignedInt8, bytes


# Data Structures

@docs maybe, list, array, dict, set, tuple, triple, result


# Object Primitives

@docs ObjectCodec, object, field, buildObject


# Custom Types

@docs CustomCodec, custom, variant0, variant1, variant2, variant3, variant4, variant5, variant6, variant7, variant8, buildCustom


# Mapping

@docs map


# Fancy Codecs

@docs constant, lazy, recursive, customWithIdCodec

-}

import Array exposing (Array)
import Bytes
import Bytes.Decode as BD
import Bytes.Encode as BE
import Dict exposing (Dict)
import Set exposing (Set)



-- DEFINITION


{-| A value that knows how to encode and decode a sequence of bytes.
-}
type Codec a
    = Codec
        { encoder : a -> Encoder
        , decoder : Decoder a
        }


{-| Describes how to generate a sequence of bytes.
-}
type alias Encoder =
    BE.Encoder


{-| The direction bytes are ordered in memory. Refer to the [elm/bytes docs][endianness] for more information.

[endianness]: https://package.elm-lang.org/packages/elm/bytes/latest/Bytes#Endianness

-}
type alias Endianness =
    Bytes.Endianness


{-| A sequence of bytes. Refer to the [elm/bytes docs][bytes] for more information.

[bytes]: https://package.elm-lang.org/packages/elm/bytes/latest/Bytes#Bytes

-}
type alias Bytes =
    Bytes.Bytes



-- DECODE


{-| Describes how to turn a sequence of bytes into a nice Elm value.
-}
type alias Decoder a =
    BD.Decoder a


endian : Endianness
endian =
    Bytes.BE


{-| Extracts the `Decoder` contained inside the `Codec`.
-}
decoder : Codec a -> Decoder a
decoder (Codec m) =
    m.decoder


{-| Run a `Codec` to turn a sequence of bytes into an Elm value.
-}
decodeValue : Codec a -> Bytes -> Maybe a
decodeValue codec =
    BD.decode (decoder codec)



-- ENCODE


{-| Extracts the encoding function contained inside the `Codec`.
-}
encoder : Codec a -> a -> Encoder
encoder (Codec m) =
    m.encoder


{-| Convert an Elm value into a sequence of bytes.
-}
encodeToValue : Codec a -> a -> Bytes
encodeToValue codec value =
    encoder codec value |> BE.encode



-- BASE


{-| If necessary you can create your own `Codec` directly.
This should be a measure of last resort though! If you need to encode and decode records and custom types, use `object` and `custom` respectively.
-}
build : (a -> Encoder) -> Decoder a -> Codec a
build encoder_ decoder_ =
    Codec
        { encoder = encoder_
        , decoder = decoder_
        }


{-| `Codec` between a sequence of bytes and an Elm `String`
-}
string : Codec String
string =
    build
        (\text ->
            BE.sequence
                [ BE.unsignedInt32 endian (BE.getStringWidth text)
                , BE.string text
                ]
        )
        (BD.unsignedInt32 endian |> BD.andThen (\charCount -> BD.string charCount))


{-| `Codec` between a sequence of bytes and an Elm `Bool`
-}
bool : Codec Bool
bool =
    build
        (\value ->
            if value then
                BE.unsignedInt8 1

            else
                BE.unsignedInt8 0
        )
        (BD.unsignedInt8
            |> BD.andThen
                (\value ->
                    case value of
                        0 ->
                            BD.succeed False

                        1 ->
                            BD.succeed True

                        _ ->
                            BD.fail
                )
        )


{-| `Codec` between a signed 32-bit integer and an Elm `Int`.
Use this if the byte ordering and number of bytes used isn't a concern.
-}
signedInt : Codec Int
signedInt =
    signedInt32 endian


{-| `Codec` between an unsigned 32-bit integer and an Elm `Int`.
Use this if the byte ordering and number of bytes used isn't a concern.
-}
unsignedInt : Codec Int
unsignedInt =
    unsignedInt32 endian


{-| `Codec` between a signed 32-bit integer and an Elm `Int`
-}
signedInt32 : Endianness -> Codec Int
signedInt32 endianness =
    build (BE.signedInt32 endianness) (BD.signedInt32 endianness)


{-| `Codec` between an unsigned 32-bit integer and an Elm `Int`
-}
unsignedInt32 : Endianness -> Codec Int
unsignedInt32 endianness =
    build (BE.unsignedInt32 endianness) (BD.unsignedInt32 endianness)


{-| `Codec` between a signed 16-bit integer and an Elm `Int`
-}
signedInt16 : Endianness -> Codec Int
signedInt16 endianness =
    build (BE.signedInt16 endianness) (BD.signedInt16 endianness)


{-| `Codec` between an unsigned 16-bit integer and an Elm `Int`
-}
unsignedInt16 : Endianness -> Codec Int
unsignedInt16 endianness =
    build (BE.unsignedInt16 endianness) (BD.unsignedInt16 endianness)


{-| `Codec` between a signed 8-bit integer and an Elm `Int`
-}
signedInt8 : Codec Int
signedInt8 =
    build BE.signedInt8 BD.signedInt8


{-| `Codec` between an unsigned 8-bit integer and an Elm `Int`
-}
unsignedInt8 : Codec Int
unsignedInt8 =
    build BE.unsignedInt8 BD.unsignedInt8


{-| `Codec` between a 64-bit float and an Elm `Float`
-}
float64 : Codec Float
float64 =
    build (BE.float64 endian) (BD.float64 endian)


{-| `Codec` between a 32-bit float and an Elm `Float`.
Due to Elm `Float`s being 64-bit, encoding and decoding it as a 32-bit float won't exactly equal the original value.
-}
float32 : Codec Float
float32 =
    build (BE.float32 endian) (BD.float32 endian)


{-| `Codec` between a sequence of bytes and an Elm `Char`
-}
char : Codec Char
char =
    build
        (String.fromChar >> encoder string)
        (decoder string
            |> BD.andThen
                (String.toList >> List.head >> Maybe.map BD.succeed >> Maybe.withDefault BD.fail)
        )



-- DATA STRUCTURES


{-| Represents an optional value.
-}
maybe : Codec a -> Codec (Maybe a)
maybe codec =
    Codec
        { decoder =
            BD.unsignedInt8
                |> BD.andThen
                    (\value ->
                        case value of
                            0 ->
                                BD.succeed Nothing

                            1 ->
                                decoder codec |> BD.map Just

                            _ ->
                                BD.fail
                    )
        , encoder =
            \v ->
                case v of
                    Nothing ->
                        BE.unsignedInt8 0

                    Just x ->
                        BE.sequence
                            [ BE.unsignedInt8 1
                            , encoder codec x
                            ]
        }


{-| `Codec` between a sequence of bytes and an Elm `List`.
-}
list : Codec a -> Codec (List a)
list codec =
    Codec
        { encoder = listEncode (encoder codec)
        , decoder =
            BD.unsignedInt32 endian
                |> BD.andThen
                    (\length -> BD.loop ( length, [] ) (listStep (decoder codec)))
        }


listEncode : (a -> Encoder) -> List a -> Encoder
listEncode encoder_ list_ =
    list_
        |> List.map encoder_
        |> List.reverse
        |> (::) (BE.unsignedInt32 endian (List.length list_))
        |> BE.sequence


listStep : BD.Decoder a -> ( Int, List a ) -> Decoder (BD.Step ( Int, List a ) (List a))
listStep decoder_ ( n, xs ) =
    if n <= 0 then
        BD.succeed (BD.Done xs)

    else
        BD.map (\x -> BD.Loop ( n - 1, x :: xs )) decoder_


{-| `Codec` between a sequence of bytes and an Elm `Array`.
-}
array : Codec a -> Codec (Array a)
array codec =
    list codec |> map Array.fromList Array.toList


{-| `Codec` between a sequence of bytes and an Elm `Dict`.
-}
dict : Codec comparable -> Codec a -> Codec (Dict comparable a)
dict keyCodec valueCodec =
    list (tuple keyCodec valueCodec) |> map Dict.fromList Dict.toList


{-| `Codec` between a sequence of bytes and an Elm `Set`.
-}
set : Codec comparable -> Codec (Set comparable)
set codec =
    list codec |> map Set.fromList Set.toList


{-| `Codec` between a sequence of bytes and an Elm `Tuple`.
-}
tuple : Codec a -> Codec b -> Codec ( a, b )
tuple m1 m2 =
    Codec
        { encoder =
            \( v1, v2 ) ->
                BE.sequence
                    [ encoder m1 v1
                    , encoder m2 v2
                    ]
        , decoder =
            BD.map2
                (\a b -> ( a, b ))
                (decoder m1)
                (decoder m2)
        }


{-| `Codec` between a sequence of bytes and an Elm triple.
-}
triple : Codec a -> Codec b -> Codec c -> Codec ( a, b, c )
triple m1 m2 m3 =
    Codec
        { encoder =
            \( v1, v2, v3 ) ->
                BE.sequence
                    [ encoder m1 v1
                    , encoder m2 v2
                    , encoder m3 v3
                    ]
        , decoder =
            BD.map3
                (\a b c -> ( a, b, c ))
                (decoder m1)
                (decoder m2)
                (decoder m3)
        }


{-| `Codec` for `Result` values.
-}
result : Codec error -> Codec value -> Codec (Result error value)
result errorCodec valueCodec =
    custom
        (\ferr fok value ->
            case value of
                Err err ->
                    ferr err

                Ok ok ->
                    fok ok
        )
        |> variant1 0 Err errorCodec
        |> variant1 1 Ok valueCodec
        |> buildCustom


{-| `Codec` for `Bytes`. This is useful if you wanted to include binary data that you're going to decode elsewhere such as a PNG file.
-}
bytes : Codec Bytes
bytes =
    Codec
        { encoder =
            \bytes_ ->
                BE.sequence
                    [ BE.unsignedInt32 endian (Bytes.width bytes_)
                    , BE.bytes bytes_
                    ]
        , decoder = BD.unsignedInt32 endian |> BD.andThen (\length -> BD.bytes length)
        }



-- OBJECTS


{-| A partially built `Codec` for an object.
-}
type ObjectCodec a b
    = ObjectCodec
        { encoder : a -> List Encoder
        , decoder : Decoder b
        }


{-| Start creating a `Codec` for an object. You should pass the main constructor as argument.
If you don't have one (for example it's a simple type with no name), you should pass a function that given the field values builds an object.

    type alias Point =
        { x : Int
        , y : Int
        }

    pointCodec : Codec Point
    pointCodec =
        Codec.object Point
            |> Codec.field .x Codec.signedInt
            |> Codec.field .y Codec.signedInt
            |> Codec.buildObject

-}
object : b -> ObjectCodec a b
object ctor =
    ObjectCodec
        { encoder = \_ -> []
        , decoder = BD.succeed ctor
        }


{-| Specify how to get a value from the object we want to encode and then give a `Codec` for that value.
-}
field : (a -> f) -> Codec f -> ObjectCodec a (f -> b) -> ObjectCodec a b
field getter codec (ObjectCodec ocodec) =
    ObjectCodec
        { encoder = \v -> (encoder codec <| getter v) :: ocodec.encoder v
        , decoder = BD.map2 (\f x -> f x) ocodec.decoder (decoder codec)
        }


{-| Create a `Codec` from a fully specified `ObjectCodec`.
-}
buildObject : ObjectCodec a a -> Codec a
buildObject (ObjectCodec om) =
    Codec
        { encoder = om.encoder >> List.reverse >> BE.sequence
        , decoder = om.decoder
        }



-- CUSTOM


{-| A partially built `Codec` for a custom type.
-}
type CustomCodec match v
    = CustomCodec
        { match : match
        , decoder : Int -> Decoder v -> Decoder v
        , idCodec : Codec Int
        }


{-| Starts building a `Codec` for a custom type.
You need to pass a pattern matching function, see the FAQ for details.

    type Semaphore
        = Red Int String Bool
        | Yellow Float
        | Green

    semaphoreCodec : Codec Semaphore
    semaphoreCodec =
        Codec.custom
            (\redEncoder yellowEncoder greenEncoder value ->
                case value of
                    Red i s b ->
                        redEncoder i s b

                    Yellow f ->
                        yellowEncoder f

                    Green ->
                        greenEncoder
            )
            |> Codec.variant3 0 Red Codec.signedInt Codec.string Codec.bool
            |> Codec.variant1 1 Yellow Codec.float64
            |> Codec.variant0 2 Green
            |> Codec.buildCustom

-}
custom : match -> CustomCodec match value
custom match =
    customWithIdCodec signedInt match


variant :
    Int
    -> ((List Encoder -> Encoder) -> a)
    -> Decoder v
    -> CustomCodec (a -> b) v
    -> CustomCodec b v
variant name matchPiece decoderPiece (CustomCodec am) =
    let
        enc v =
            encoder am.idCodec name
                :: v
                |> BE.sequence

        decoder_ tag orElse =
            if tag == name then
                decoderPiece

            else
                am.decoder tag orElse
    in
    CustomCodec
        { match = am.match <| matchPiece enc
        , decoder = decoder_
        , idCodec = am.idCodec
        }


{-| Define a variant with 0 parameters for a custom type.
-}
variant0 :
    Int
    -> v
    -> CustomCodec (Encoder -> a) v
    -> CustomCodec a v
variant0 name ctor =
    variant name
        (\c -> c [])
        (BD.succeed ctor)


{-| Define a variant with 1 parameters for a custom type.
-}
variant1 :
    Int
    -> (a -> v)
    -> Codec a
    -> CustomCodec ((a -> Encoder) -> b) v
    -> CustomCodec b v
variant1 name ctor m1 =
    variant name
        (\c v ->
            c
                [ encoder m1 v
                ]
        )
        (BD.map ctor
            (decoder m1)
        )


{-| Define a variant with 2 parameters for a custom type.
-}
variant2 :
    Int
    -> (a -> b -> v)
    -> Codec a
    -> Codec b
    -> CustomCodec ((a -> b -> Encoder) -> c) v
    -> CustomCodec c v
variant2 id ctor m1 m2 =
    variant id
        (\c v1 v2 ->
            c
                [ encoder m1 v1
                , encoder m2 v2
                ]
        )
        (BD.map2 ctor
            (decoder m1)
            (decoder m2)
        )


{-| Define a variant with 3 parameters for a custom type.
-}
variant3 :
    Int
    -> (a -> b -> c -> v)
    -> Codec a
    -> Codec b
    -> Codec c
    -> CustomCodec ((a -> b -> c -> Encoder) -> partial) v
    -> CustomCodec partial v
variant3 id ctor m1 m2 m3 =
    variant id
        (\c v1 v2 v3 ->
            c
                [ encoder m1 v1
                , encoder m2 v2
                , encoder m3 v3
                ]
        )
        (BD.map3 ctor
            (decoder m1)
            (decoder m2)
            (decoder m3)
        )


{-| Define a variant with 4 parameters for a custom type.
-}
variant4 :
    Int
    -> (a -> b -> c -> d -> v)
    -> Codec a
    -> Codec b
    -> Codec c
    -> Codec d
    -> CustomCodec ((a -> b -> c -> d -> Encoder) -> partial) v
    -> CustomCodec partial v
variant4 id ctor m1 m2 m3 m4 =
    variant id
        (\c v1 v2 v3 v4 ->
            c
                [ encoder m1 v1
                , encoder m2 v2
                , encoder m3 v3
                , encoder m4 v4
                ]
        )
        (BD.map4 ctor
            (decoder m1)
            (decoder m2)
            (decoder m3)
            (decoder m4)
        )


{-| Define a variant with 5 parameters for a custom type.
-}
variant5 :
    Int
    -> (a -> b -> c -> d -> e -> v)
    -> Codec a
    -> Codec b
    -> Codec c
    -> Codec d
    -> Codec e
    -> CustomCodec ((a -> b -> c -> d -> e -> Encoder) -> partial) v
    -> CustomCodec partial v
variant5 id ctor m1 m2 m3 m4 m5 =
    variant id
        (\c v1 v2 v3 v4 v5 ->
            c
                [ encoder m1 v1
                , encoder m2 v2
                , encoder m3 v3
                , encoder m4 v4
                , encoder m5 v5
                ]
        )
        (BD.map5 ctor
            (decoder m1)
            (decoder m2)
            (decoder m3)
            (decoder m4)
            (decoder m5)
        )


{-| Define a variant with 6 parameters for a custom type.
-}
variant6 :
    Int
    -> (a -> b -> c -> d -> e -> f -> v)
    -> Codec a
    -> Codec b
    -> Codec c
    -> Codec d
    -> Codec e
    -> Codec f
    -> CustomCodec ((a -> b -> c -> d -> e -> f -> Encoder) -> partial) v
    -> CustomCodec partial v
variant6 id ctor m1 m2 m3 m4 m5 m6 =
    variant id
        (\c v1 v2 v3 v4 v5 v6 ->
            c
                [ encoder m1 v1
                , encoder m2 v2
                , encoder m3 v3
                , encoder m4 v4
                , encoder m5 v5
                , encoder m6 v6
                ]
        )
        (BD.map5 (\a b c d ( e, f ) -> ctor a b c d e f)
            (decoder m1)
            (decoder m2)
            (decoder m3)
            (decoder m4)
            (BD.map2 Tuple.pair
                (decoder m5)
                (decoder m6)
            )
        )


{-| Define a variant with 7 parameters for a custom type.
-}
variant7 :
    Int
    -> (a -> b -> c -> d -> e -> f -> g -> v)
    -> Codec a
    -> Codec b
    -> Codec c
    -> Codec d
    -> Codec e
    -> Codec f
    -> Codec g
    -> CustomCodec ((a -> b -> c -> d -> e -> f -> g -> Encoder) -> partial) v
    -> CustomCodec partial v
variant7 id ctor m1 m2 m3 m4 m5 m6 m7 =
    variant id
        (\c v1 v2 v3 v4 v5 v6 v7 ->
            c
                [ encoder m1 v1
                , encoder m2 v2
                , encoder m3 v3
                , encoder m4 v4
                , encoder m5 v5
                , encoder m6 v6
                , encoder m7 v7
                ]
        )
        (BD.map5 (\a b c ( d, e ) ( f, g ) -> ctor a b c d e f g)
            (decoder m1)
            (decoder m2)
            (decoder m3)
            (BD.map2 Tuple.pair
                (decoder m4)
                (decoder m5)
            )
            (BD.map2 Tuple.pair
                (decoder m6)
                (decoder m7)
            )
        )


{-| Define a variant with 8 parameters for a custom type.
-}
variant8 :
    Int
    -> (a -> b -> c -> d -> e -> f -> g -> h -> v)
    -> Codec a
    -> Codec b
    -> Codec c
    -> Codec d
    -> Codec e
    -> Codec f
    -> Codec g
    -> Codec h
    -> CustomCodec ((a -> b -> c -> d -> e -> f -> g -> h -> Encoder) -> partial) v
    -> CustomCodec partial v
variant8 id ctor m1 m2 m3 m4 m5 m6 m7 m8 =
    variant id
        (\c v1 v2 v3 v4 v5 v6 v7 v8 ->
            c
                [ encoder m1 v1
                , encoder m2 v2
                , encoder m3 v3
                , encoder m4 v4
                , encoder m5 v5
                , encoder m6 v6
                , encoder m7 v7
                , encoder m8 v8
                ]
        )
        (BD.map5 (\a b ( c, d ) ( e, f ) ( g, h ) -> ctor a b c d e f g h)
            (decoder m1)
            (decoder m2)
            (BD.map2 Tuple.pair
                (decoder m3)
                (decoder m4)
            )
            (BD.map2 Tuple.pair
                (decoder m5)
                (decoder m6)
            )
            (BD.map2 Tuple.pair
                (decoder m7)
                (decoder m8)
            )
        )


{-| Build a `Codec` for a fully specified custom type.
-}
buildCustom : CustomCodec (a -> Encoder) a -> Codec a
buildCustom (CustomCodec am) =
    Codec
        { encoder = \v -> am.match v
        , decoder =
            decoder am.idCodec
                |> BD.andThen
                    (\tag ->
                        am.decoder tag BD.fail
                    )
        }



-- MAPPING


{-| Transform a `Codec`.
-}
map : (a -> b) -> (b -> a) -> Codec a -> Codec b
map fromBytes toBytes codec =
    Codec
        { decoder = BD.map fromBytes <| decoder codec
        , encoder = \v -> toBytes v |> encoder codec
        }


{-| Transform a `Codec` in a way that can potentially fail when decoding.

    {-| Volume must be between 0 and 1.
    -}
    volumeCodec =
        Codec.float64
            |> Codec.andThen
                (\volume ->
                    if volume <= 1 && volume >= 0 then
                        Just volume

                    else
                        Nothing
                )
                (\volume -> volume)

-}
andThen : (a -> Maybe b) -> (b -> a) -> Codec a -> Codec b
andThen fromBytes toBytes codec =
    Codec
        { decoder =
            decoder codec
                |> BD.andThen
                    (\value ->
                        case fromBytes value of
                            Just newValue ->
                                BD.succeed newValue

                            Nothing ->
                                BD.fail
                    )
        , encoder = \v -> toBytes v |> encoder codec
        }



-- FANCY


{-| Create a `Codec` for a recursive data structure.
The argument to the function you need to pass is the fully formed `Codec`, see the FAQ for details.

    type Peano
        = Peano (Maybe Peano)

    peanoCodec : Codec Peano
    peanoCodec =
        Codec.recursive
            (\finishedCodec ->
                Codec.maybe finishedCodec
                    |> Codec.map Peano (\(Peano p) -> p)
            )

-}
recursive : (Codec a -> Codec a) -> Codec a
recursive f =
    let
        step =
            { decoder = BD.succeed () |> BD.andThen (\() -> recursive f |> decoder)
            , encoder = \value -> encoder (recursive f) value
            }
    in
    f <| Codec step


{-| This is useful for recursive structures that are not easily modeled with `recursive`.

    type Peano
        = Peano (Maybe Peano)

    {-| This is the same example used in Codec.recursive but adapted for lazy.
    -}
    peanoCodec : Codec Peano
    peanoCodec =
        Codec.maybe (Codec.lazy (\() -> peanoCodec)) |> Codec.map Peano (\(Peano a) -> a)

-}
lazy : (() -> Codec a) -> Codec a
lazy f =
    Codec
        { decoder = BD.succeed () |> BD.andThen (\() -> decoder (f ()))
        , encoder = \value -> encoder (f ()) value
        }


{-| Same as `custom` but here we can choose what codec to use for the integer id we tell apart variants with.
This is useful if, for example, you know you won't have ids outside of the range 0 - 255 and can use unsignedInt8 instead of the default signedInt32 to save some space.
-}
customWithIdCodec : Codec Int -> match -> CustomCodec match value
customWithIdCodec idCodec match =
    CustomCodec
        { match = match
        , decoder = \_ -> identity
        , idCodec = idCodec
        }


{-| Create a `Codec` that encodes nothing and always decodes as the same value.
-}
constant : a -> Codec a
constant default_ =
    Codec
        { decoder = BD.succeed default_
        , encoder = \_ -> BE.sequence []
        }
