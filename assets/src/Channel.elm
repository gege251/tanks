port module Channel exposing
    ( Channel
    , Response(..)
    , Socket
    , connect
    , fire
    , join
    , leave
    , moveTank
    , moveTurret
    , push
    , subscribe
    )

import Data.GameState as GameState exposing (GameState)
import Data.Tank as Tank exposing (Tank)
import Json.Decode as Decode exposing (Decoder, Value)
import Json.Encode as Encode


port channelFromElm : { msg : String, payload : Value } -> Cmd msg


port channelToElm : ({ msg : String, payload : Value } -> msg) -> Sub msg


type Socket
    = Socket Value


type Channel
    = Channel Value


connect : String -> Cmd msg
connect playerName =
    channelFromElm
        { msg = "connect"
        , payload =
            Encode.object
                [ ( "playerName", Encode.string playerName )
                ]
        }


join : Socket -> String -> Cmd msg
join (Socket socket) topic =
    channelFromElm
        { msg = "join"
        , payload =
            Encode.object
                [ ( "socket", socket )
                , ( "topic", Encode.string topic )
                ]
        }


push : Channel -> Push -> Cmd msg
push (Channel channel) { event, value } =
    channelFromElm
        { msg = "push"
        , payload =
            Encode.object
                [ ( "channel", channel )
                , ( "event", Encode.string event )
                , ( "value", value )
                ]
        }


leave : Channel -> Cmd msg
leave (Channel channel) =
    channelFromElm
        { msg = "leave"
        , payload =
            Encode.object [ ( "channel", channel ) ]
        }


type alias Push =
    { event : String, value : Value }


type Response
    = Sync GameState
    | EndBattle (List Tank)


type alias GotSocket msg =
    Result Decode.Error Socket -> msg


type alias GotChannel msg =
    Result Decode.Error Channel -> msg


type alias GotChannelResponse msg =
    Result Decode.Error Response -> msg


subscribe : GotSocket msg -> GotChannel msg -> GotChannelResponse msg -> Sub msg
subscribe gotSocket gotChannel gotChannelResponse =
    channelToElm <|
        \{ msg, payload } ->
            case msg of
                "got_socket" ->
                    Decode.decodeValue socketDecoder payload
                        |> gotSocket

                "got_channel" ->
                    Decode.decodeValue channelDecoder payload
                        |> gotChannel

                "got_channel_event" ->
                    Decode.decodeValue responseDecoder payload
                        |> gotChannelResponse

                eventName ->
                    Decode.decodeValue (Decode.fail <| "unknown event name " ++ eventName) payload
                        |> gotChannelResponse


socketDecoder : Decoder Socket
socketDecoder =
    Decode.field "socket" Decode.value
        |> Decode.map Socket


channelDecoder : Decoder Channel
channelDecoder =
    Decode.field "channel" Decode.value
        |> Decode.map Channel


responseDecoder : Decoder Response
responseDecoder =
    let
        decodeHelper event =
            case event of
                "sync" ->
                    Decode.field "value" GameState.decoder
                        |> Decode.map Sync

                "end_battle" ->
                    Decode.field "value" (Decode.field "tanks" (Decode.list Tank.decoder))
                        |> Decode.map EndBattle

                _ ->
                    Decode.fail "unknown channel event"
    in
    Decode.field "event" Decode.string
        |> Decode.andThen decodeHelper


moveTank : Channel -> Int -> Cmd msg
moveTank channel val =
    push channel (Push "move" <| Encode.object [ ( "move", Encode.int val ) ])


moveTurret : Channel -> Float -> Cmd msg
moveTurret channel val =
    push channel (Push "move_turret" <| Encode.object [ ( "angle", Encode.float val ) ])


fire : Channel -> Cmd msg
fire channel =
    push channel (Push "fire" <| Encode.object [])
