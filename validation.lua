---@namespace Reskins.SpriteUtils

local _config = require("validation.config")
local _primitives = require("validation.primitives")
local _collections = require("validation.collections")
local _combinators = require("validation.combinators")
local _signature = require("validation.signature")

---Builds reusable validators for method arguments and data structures.
---
---A validator is defined once, from rules, and then applied wherever it is
---needed — the inverse of describing a value's requirements afresh at every call
---site. Builder methods never mutate, so a validator shared from a catalog can
---be extended by any caller without disturbing the original.
---
---For the Factorio structures this library already describes — icons, colors,
---vectors, file paths — see `validation.common`, which is built from these
---pieces.
---
---Nothing here depends on a particular mod loading stage.
---
---### Examples
---```lua
---local V = require("__reskins-sprite-utils__.validation")
---
----- Defined once, at load:
---local PipeMaterial = V.one_of(_defines.pipe_material)
---local AntennaVariant = V.integer():in_range(0, 4)
---
----- Reused at every call site:
---function M.get_roboport(pipe_material, antenna_variant)
---    PipeMaterial:assert(pipe_material, "pipe_material")
---    AntennaVariant:assert(antenna_variant, "antenna_variant")
---    ...
---end
---```
---@class Validation
local _validation = {}

-- Primitives.
_validation.any = _primitives.any
_validation.boolean = _primitives.boolean
_validation.func = _primitives.func
_validation.integer = _primitives.integer
_validation.number = _primitives.number
_validation.string = _primitives.string
_validation.table = _primitives.table

-- Collections.
_validation.array = _collections.array
_validation.map = _collections.map
_validation.shape = _collections.shape
_validation.tuple = _collections.tuple

-- Combinators.
_validation.all_of = _combinators.all_of
_validation.any_of = _combinators.any_of
_validation.custom = _combinators.custom
_validation.lazy = _combinators.lazy
_validation.literal = _combinators.literal
_validation.one_of = _combinators.one_of

-- Whole-signature checking.
_validation.signature = _signature.signature

-- Reporting behavior.
_validation.get_behavior = _config.get_behavior
_validation.set_behavior = _config.set_behavior
_validation.reset_behavior = _config.reset_behavior

return _validation
