module Cornelis.Vim.Compat where

import Data.Int (Int64)
import Data.Map (Map)
import Data.Text (Text)
import Data.Vector (Vector)
import qualified Data.Vector as Vector
import Neovim
import Neovim.API.Text (Buffer, Window)
import qualified Neovim.API.Text as Vim

-- This branch builds against nvim-hs @ main (2.3.2.7), whose API code
-- generation understands Neovim 0.12's api-info format and produces TYPED
-- bindings (Vector Window, (Int64, Int64), Vector Text, ...).
-- The original nvim-0.12 branch expected the untyped "Vector Object"
-- fallback that nvim-hs 2.3.2.4 produced for pre-release 0.12 api-info.

nvim_list_wins :: Neovim env [Window]
nvim_list_wins = Vector.toList <$> Vim.nvim_list_wins

window_get_cursor :: Window -> Neovim env (Int, Int)
window_get_cursor w = do
    (r, c) <- Vim.window_get_cursor w
    pure (fromIntegral r, fromIntegral c)

window_set_cursor :: Window -> (Int, Int) -> Neovim env ()
window_set_cursor w (r, c) = Vim.window_set_cursor w (fromIntegral r, fromIntegral c)

nvim_buf_get_lines :: Buffer -> Int64 -> Int64 -> Bool -> Neovim env [Text]
nvim_buf_get_lines b s e flag = Vector.toList <$> Vim.nvim_buf_get_lines b s e flag

nvim_buf_get_lines' :: Buffer -> Int64 -> Int64 -> Bool -> Neovim env (Vector Text)
nvim_buf_get_lines' = Vim.nvim_buf_get_lines

nvim_buf_set_text ::
    Buffer -> Int64 -> Int64 -> Int64 -> Int64 -> [Text] -> Neovim env ()
nvim_buf_set_text b sl sc el ec = Vim.nvim_buf_set_text b sl sc el ec . Vector.fromList

-- Neovim 0.12 declares nvim_buf_get_extmarks as returning
-- ArrayOf(DictAs(get_extmark_item)), which nvim-hs maps to
-- Vector (Map Text Object). On the wire the items are still
-- [extmark_id, row, col, details?] TUPLES, so the typed binding would fail
-- to decode at runtime. Call it through nvim_call_function instead and keep
-- the raw Objects (same trick as Cornelis.Vim.getExtmarkIntervalById).
nvim_buf_get_extmarks ::
    Buffer -> Int64 -> Object -> Object -> Map Text Object -> Neovim env (Vector Object)
nvim_buf_get_extmarks b nsid s e opts = do
    res <-
        Vim.nvim_call_function "nvim_buf_get_extmarks" $
            Vector.fromList [toObject b, toObject nsid, s, e, ObjectMap opts]
    case res of
        ObjectArray v -> pure v
        _ -> pure Vector.empty
