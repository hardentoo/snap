{-# LANGUAGE CPP                #-}
{-# LANGUAGE OverloadedStrings  #-}
{-# LANGUAGE DeriveDataTypeable #-}

module Snap.Snaplet.Config where

------------------------------------------------------------------------------
import Data.Function                    (on)
import Data.Maybe                       (fromMaybe)
import Data.Monoid                      (Last(..), getLast)

#if MIN_VERSION_base(4,10,0)
import           Data.Typeable          (Typeable)
#elif MIN_VERSION_base(4,7,0)
import           Data.Typeable.Internal (Typeable)
#else
import           Data.Typeable          (Typeable, TyCon, mkTyCon,
                                         mkTyConApp, typeOf)
#endif

#if !MIN_VERSION_base(4,8,0)
import Data.Monoid                      (Monoid, mappend, mempty)
#endif

import System.Console.GetOpt            (OptDescr(Option), ArgDescr(ReqArg))
------------------------------------------------------------------------------
import Snap.Core
import Snap.Http.Server.Config (Config, fmapOpt, setOther, getOther, optDescrs
                               ,extendedCommandLineConfig)


------------------------------------------------------------------------------
-- | AppConfig contains the config options for command line arguments in
-- snaplet-based apps.
newtype AppConfig = AppConfig { appEnvironment :: Maybe String }
#if MIN_VERSION_base(4,7,0)
  deriving Typeable
#else

------------------------------------------------------------------------------
-- | AppConfig has a manual instance of Typeable due to limitations in the
-- tools available before GHC 7.4, and the need to make dynamic loading
-- tractable.  When support for earlier versions of GHC is dropped, the
-- dynamic loader package can be updated so that manual Typeable instances
-- are no longer needed.
appConfigTyCon :: TyCon
appConfigTyCon = mkTyCon "Snap.Snaplet.Config.AppConfig"
{-# NOINLINE appConfigTyCon #-}

instance Typeable AppConfig where
    typeOf _ = mkTyConApp appConfigTyCon []
#endif

------------------------------------------------------------------------------
instance Monoid AppConfig where
    mempty = AppConfig Nothing
    mappend a b = AppConfig
        { appEnvironment = ov appEnvironment a b
        }
      where
        ov f x y = getLast $! (mappend `on` (Last . f)) x y


------------------------------------------------------------------------------
-- | Command line options for snaplet applications.
appOpts :: AppConfig -> [OptDescr (Maybe (Config m AppConfig))]
appOpts defaults = map (fmapOpt $ fmap (flip setOther mempty))
    [ Option ['e'] ["environment"]
             (ReqArg setter "ENVIRONMENT")
             $ "runtime environment to use" ++ defaultC appEnvironment
    ]
  where
    setter s = Just $ mempty { appEnvironment = Just s}
    defaultC f = maybe "" ((", default " ++) . show) $ f defaults


------------------------------------------------------------------------------
-- | Calls snap-server's extendedCommandLineConfig to add snaplet options to
-- the built-in server command line options.
commandLineAppConfig :: MonadSnap m
                     => Config m AppConfig
                     -> IO (Config m AppConfig)
commandLineAppConfig defaults =
    extendedCommandLineConfig (appOpts appDefaults ++ optDescrs defaults)
                              mappend defaults
  where
    appDefaults = fromMaybe mempty $ getOther defaults
