module Data.Session exposing (Session, init, setPlayer, updateSession)

import Browser.Navigation as Nav
import Data.Player exposing (Player)
import Data.String20 as String20 exposing (String20)


type alias Session =
    { player : Maybe Player
    , navKey : Nav.Key
    }


init : Nav.Key -> Maybe String -> Session
init navKey playerName =
    { player = Nothing -- playerName |> Maybe.andThen String20.create |> Maybe.map Player
    , navKey = navKey
    }


setPlayer : Maybe Player -> Session -> Session
setPlayer player session =
    { session | player = player }


updateSession : Session -> { r | session : Session } -> { r | session : Session }
updateSession session model =
    { model | session = session }
