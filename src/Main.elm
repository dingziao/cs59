port module Main exposing (main)

import Browser
import Html exposing (Html, button, div, footer, h1, input, li, p, span, text, ul)
import Html.Attributes exposing (class, placeholder, value, attribute)
import Html.Events exposing (onClick, onInput, on)
import Json.Decode as Decode exposing (Decoder)
import String


-- MODEL

type alias Model =
    { input : String
    , messages : List ( String, String )
    , progress : Float
    , loadingText : String
    , ready : Bool
    , waitingForReply : Bool
    }

init : () -> ( Model, Cmd Msg )
init _ =
    ( { input = ""
      , messages = [ ("system", "WebLLM Elm ports demo") ]
      , progress = 0
      , loadingText = ""
      , ready = False
      , waitingForReply = False
      }
    , Cmd.none
    )


-- MESSAGES

type Msg
    = NoOp
    | UpdateInput String
    | Send
    | Received String


-- UPDATE

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        UpdateInput s ->
            ( { model | input = s }, Cmd.none )

        Send ->
            let
                user = model.input
                cmd = sendToJs user
                newModel = { model | input = "", messages = model.messages ++ [ ("user", user) ], waitingForReply = True }
            in
            ( newModel, cmd )

        Received text ->
            case Decode.decodeString incomingDecoder text of
                Ok incoming ->
                    case incoming of
                        Progress p txt ->
                            ( { model | progress = p, loadingText = txt }, Cmd.none )

                        Ready mdl ->
                            ( { model | ready = True, loadingText = "Ready: " ++ mdl, progress = 1, waitingForReply = False }, Cmd.none )

                        Reply txt raw ->
                            -- Only display the textual reply to keep the UI clean.
                            ( { model | messages = model.messages ++ [ ("assistant", txt) ], waitingForReply = False }, Cmd.none )

                        ErrMsg e ->
                            ( { model | messages = model.messages ++ [ ("system", "Error: " ++ e) ], waitingForReply = False }, Cmd.none )

                Err _ ->
                    -- If we couldn't parse JSON, append raw text as assistant reply
                    ( { model | messages = model.messages ++ [ ("assistant", text) ], waitingForReply = False }, Cmd.none )



-- VIEW

view : Model -> Html Msg
view model =
    div [ class "app" ]
        [ -- Progress area
                    div [ class "progress-area" ]
                        [ div [ class "progress-row" ]
                                [ viewBagel
                                , div [ class "progress-label" ] [ text (if model.ready then "Model ready" else model.loadingText) ]
                                ]
                        , div [ class "progress-bar-outer", attribute "style" "width: 100%; background: #222; height: 14px; border-radius: 8px;" ]
                                [ div [ class "progress-bar-inner", attribute "style" ("width: " ++ String.fromFloat (model.progress * 100) ++ "% ; background: #6ee7b7; height: 100%; border-radius: 8px;") ] [] ]
                        ]

        , div [ class "chat" ]
            [ ul [ class "messages" ]
                (List.append (List.map viewMessage model.messages)
                    (if model.waitingForReply then [ viewTyping ] else []))
            , div [ class "chat-input" ]
                [ input [ placeholder "Type a message...", value model.input, onInput UpdateInput, class "task-input", on "keydown" (Decode.map (\k -> if k == "Enter" then Send else NoOp) (Decode.field "key" Decode.string)) ] []
                , button [ class "btn small", onClick Send ] [ text "Send" ]
                ]
            ]

        , footer [] [ p [] [ text "Demo: Elm + WebLLM via ports" ] ]
        ]


viewMessage : ( String, String ) -> Html Msg
viewMessage ( role, txt ) =
    let
        cls = "msg " ++ role
    in
    li [ class cls ]
        [ span [ class "msg-role" ] [ text (role ++ ":") ]
        , span [ class "msg-text" ] [ text (" " ++ txt) ]
        ]


viewTyping : Html Msg
viewTyping =
    li [ class "msg assistant typing" ]
        [ span [ class "typing" ]
            [ span [ class "dot" ] []
            , span [ class "dot" ] []
            , span [ class "dot" ] []
            ]
        ]


viewBagel : Html Msg
viewBagel =
    div [ class "bagel", attribute "aria-hidden" "true" ] []



-- JSON incoming decoding
type Incoming
    = Progress Float String
    | Ready String
    | Reply String String
    | ErrMsg String

incomingDecoder : Decoder Incoming
incomingDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\t ->
                case t of
                    "progress" ->
                        Decode.map2 Progress
                            (Decode.field "data" (Decode.field "progress" Decode.float))
                            (Decode.field "data" (Decode.field "text" Decode.string))

                    "ready" ->
                        Decode.map Ready (Decode.field "model" Decode.string)

                    "reply" ->
                        Decode.map2 Reply
                            (Decode.field "text" Decode.string)
                            (Decode.oneOf [ Decode.field "raw" Decode.string, Decode.succeed "" ])

                    "error" ->
                        Decode.map ErrMsg (Decode.field "message" Decode.string)

                    _ ->
                        Decode.fail "unknown incoming type"
            )



-- PROGRAM

port sendToJs : String -> Cmd msg

port fromJs : (String -> msg) -> Sub msg

subscriptions : Model -> Sub Msg
subscriptions _ =
    fromJs Received

main : Program () Model Msg
main =
    Browser.element { init = init, update = update, view = view, subscriptions = subscriptions }

