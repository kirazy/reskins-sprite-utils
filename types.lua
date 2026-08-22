---@using data

---@namespace Reskins.SpriteUtils

---Represents any Prototype with the required `icons` or `icon` fields.
---@alias PrototypeWithIcons
---| AchievementPrototype
---| AmmoCategory
---| AsteroidChunkPrototype
---| EntityPrototype
---| FluidPrototype
---| ItemGroup
---| ItemPrototype
---| QualityPrototype
---| RecipePrototype
---| ShortcutPrototype
---| SpaceConnectionPrototype
---| SpaceLocationPrototype
---| SurfacePrototype
---| TechnologyPrototype
---| TilePrototype
---| TipsAndTricksItem
---| VirtualSignalPrototype

---Type names/aliases that map to icon_size defaults as per https://lua-api.factorio.com/latest/types/IconData.html#scale
---@alias IconDefaultsType
---| "default"
---| "technology"
---| "space-location"
---| "shortcut"
---| "shortcut-small"
---| "achievement"
---| "item-group"
---| string

---Represents an icon from an array of `IconData` objects that may be stored for deferred assignment.
---@class DeferrableIconData
---The name of the prototype to be assigned this icon.
---@field name string
---The type name of the prototype to be assigned this icon.
---@field type_name string
---The icon data to store for deferred assignment.
---@field icon_data IconData[]
---The pictures data to store for deferred assignment.
---@field pictures? SpriteVariations

---Represents an icon from a single `IconData` object that may be stored for deferred assignment.
---@class DeferrableIconDatum
---The name of the prototype to be assigned this icon.
---@field name string
---The type name of the prototype to be assigned this icon.
---@field type_name string
---The icon data to store for deferred assignment.
---@field icon_datum IconData

---@class TransformableIconBase
---The scale to apply to the sourced icon. Ignored when `transform` is defined. Default `nil`.
---@field scale? double
---The shift to apply to the sourced icon. Ignored when `transform` is defined. Default `nil`.
---@field shift? Vector
---The tint to apply to the sourced icon. Ignored when `transform` is defined. Default `nil`.
---@field tint? Color

---Provides the icon and optional transformations to a sourced `IconData` object.
---@class IconDatumSource : TransformableIconBase
---The icon data to be used for the icon.
---@field icon_datum IconData
---The name of the type-specific icon defaults to generate, as per https://lua-api.factorio.com/latest/types/Iconhtml#scale.
---Unrecognized names resolve to `defines.default_icon_size`.
---@field defaults_type? IconDefaultsType

---Provides the icon and optional transformations to a sourced array of `IconData` objects.
---@class IconDataSource : TransformableIconBase
---The icon data to be used for the icon.
---@field icon_data IconData[]
---The name of the type-specific icon defaults to generate, as per https://lua-api.factorio.com/latest/types/IconData.html#scale.
---Unrecognized names resolve to `defines.default_icon_size`.
---@field defaults_type? IconDefaultsType

---Provides the name and type information necessary to directly retrieve an icon
---from a source prototype, and apply a shift and scale to that icon.
---@class PrototypeIconSource : TransformableIconBase
---The name of the prototype to source the icon from.
---@field name string
---The type name of the prototype to source the icon from.
---@field type_name string

---A source of icon data, whether an explicit icon or a set of instructions on where to retrieve it.
---@alias IconSource IconDatumSource|IconDataSource|PrototypeIconSource

---An array of icon data sources, whether a mix of explicit icons or a instructions on where to retrieve icons.
---@alias IconSources (IconDatumSource|IconDataSource|PrototypeIconSource)[]

---Provides additional fields for the `Animation` object when using a sprite sheet with
---frames laid out in vertical stripes instead of the standard convention of horizontal stripes.
---@class VerticallyOrientableAnimation : Animation
---When `true`, indicates that the Animation sprites are laid out vertically and should be processed
---accordingly by `sprite_utils.make_4way_animation_from_spritesheet`.
---@field vertically_oriented? boolean
---
---If this property is present, all Animation definitions have to be placed as entries in the array,
---and they will all be loaded from there. layers may not be an empty table. Each definition in the
---array may also have the layers property.
---
---`animation_speed` and `max_advance` of the first layer are used for all layers. All layers will
---run at the same speed.
---
---If this property is present, all other properties, including those inherited from
---AnimationParameters, are ignored.
---@field layers? VerticallyOrientableAnimation[]
