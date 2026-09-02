---@namespace Reskins.SpriteUtils

local _config = require("validation.config")
local _primitives = require("validation.primitives")
local _collections = require("validation.collections")
local _combinators = require("validation.combinators")
local _signature = require("validation.signature")

---Provides reusable validators for function arguments and data structures.
---
---A validator is defined once and applied wherever it is needed. Builder methods return a new
---validator and do not modify the original. Validators for Factorio structures, such as icons,
---colors, vectors, and file paths, are provided by `validation.common`.
---
---This module may be used in any mod loading stage.
---
---#### Examples
---```lua
---local V = require("__reskins-sprite-utils__.validation")
---
----- Define once.
---local PipeMaterial = V.one_of(_defines.pipe_material)
---local AntennaVariant = V.integer():in_range(0, 4)
---
----- Reuse across multiple call sites.
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
