---cspell: words FTMK RRGGBBAA

---@using data

---@namespace Reskins.SpriteUtils

--- Provides color tools for use with Artisanal Reskins: Sprite Utils.
---
---#### Examples
---```lua
---local _colors = require("__reskins-sprite-utils__.colors")
---```
---@class Colors
local _colors = {}

local V = require("validation")
local Common = require("validation.common")

---A color in the HSVA color space.
---@class HsvColor
---The hue, in degrees. Cyclic, so `400` names the same hue as `40`.
---@field h float
---The saturation, between 0 and 1.
---@field s float
---The value, between 0 and 1.
---@field v float
---The alpha (opacity), between 0 and 1.
---@field a float

---A color in the HSLA color space.
---@class HslColor
---The hue, in degrees. Cyclic, so `400` names the same hue as `40`.
---@field h float
---The saturation, between 0 and 1.
---@field s float
---The luminance, between 0 and 1.
---@field l float
---The alpha (opacity), between 0 and 1.
---@field a float

local function clamp(v)
	return math.max(0, math.min(v, 1))
end

---Table of red, green, blue, and alpha float values between 0 and 1 as explicit key-value pairs.
---
---The game usually expects colors to be in pre-multiplied form (color channels are pre-multiplied by alpha).
---
---[View Documentation](https://lua-api.factorio.com/latest/types/Color.html)
---@class (exact) NormalizedColor
---alpha value (opacity)
---
---[View Documentation](https://lua-api.factorio.com/latest/types/Color.html%23a#a)
---@field a float
---
---blue value
---[View Documentation](https://lua-api.factorio.com/latest/types/Color.html%23b#b)
---@field b float
---green value
---
---[View Documentation](https://lua-api.factorio.com/latest/types/Color.html%23g#g)
---@field g float
---red value
---
---[View Documentation](https://lua-api.factorio.com/latest/types/Color.html%23r#r)
---@field r float

---Normalizes the given color. The color is not validated.
---@param tint Color The color to normalize.
---@return NormalizedColor # A copy of `tint` with all channels normalized and defined.
---@nodiscard
local function normalize_color(tint)
	local n = {
		r = math.max(tint.r or tint[1] or 0, 0),
		g = math.max(tint.g or tint[2] or 0, 0),
		b = math.max(tint.b or tint[3] or 0, 0),
		a = math.max(tint.a or tint[4] or 1, 0),
	}

	if math.max(n.r, n.g, n.b, n.a) > 1 then
		for key, value in pairs(n) do
			n[key] = clamp(value / 255)
		end
	end
	return n
end

local check_normalize = V.signature("normalize", {
	{ "tint", Common.color },
})

---
---Normalizes the values in the provided `tint` to between 0 and 1, and ensures
---`r`, `g`, `b`, and `a` are all defined.
---
---`tint` may use either named fields (`r`, `g`, `b`, `a`) or positional fields (`[1]`, `[2]`, `[3]`, `[4]`).
---If any channel value exceeds 1, all channels are divided by 255.
---@param tint Color The color to normalize.
---@return NormalizedColor # A copy of `tint` with all channels normalized and defined.
---
---#### Examples
---```lua
---local normalized = _colors.normalize({ r = 128, g = 191, b = 222, a = 255 })
----- Returns { r ≈ 0.502, g ≈ 0.749, b ≈ 0.871, a = 1.0 }
---```
---@throws Thrown when `tint` is `nil`.
---@throws Thrown when `tint` is not a `Color`.
---@nodiscard
function _colors.normalize(tint)
	check_normalize(tint)

	return normalize_color(tint)
end

---The largest difference any one channel may have and still read as the same
---color, in normalized channel units.
---
---Half an 8-bit step: colors that round to the same value on the 255-step scale
---the game renders at compare equal.
local default_tolerance = 0.5 / 255

local check_are_equal = V.signature("are_equal", {
	{ "c1", Common.color },
	{ "c2", Common.color },
	{ "tolerance", Common.unit_interval:optional() },
})

---
---Compares the provided colors `c1` and `c2` channel by channel, treating them
---as the same color when every channel, including alpha, agrees to within
---`tolerance`.
---
---`c1` and `c2` are not required to be normalized beforehand, so a color written
---on the 0–255 scale and the same color written on the 0–1 scale compare equal.
---
---#### Parameters
---@param c1 Color The first color.
---@param c2 Color The second color.
---@param tolerance? float The largest difference allowed between matching channels, from 0 to 1. When `0`, the channels must match exactly. Default `0.5 / 255`.
---
---#### Returns
---@return boolean # `true` if every channel of `c1` is within `tolerance` of the matching channel of `c2`; otherwise, `false`.
---
---#### Examples
---```lua
---local same = _colors.are_equal({ r = 255, g = 0, b = 0, a = 255 }, { r = 1, g = 0, b = 0, a = 1 })
----- Returns true
---
---local exact = _colors.are_equal({ r = 0.5, g = 0, b = 0, a = 1 }, { r = 0.5001, g = 0, b = 0, a = 1 }, 0)
----- Returns false
---```
---@throws Thrown when `c1` or `c2` is `nil`.
---@throws Thrown when `c1` or `c2` is not a `Color`.
---@throws Thrown when `tolerance` is not between 0 and 1.
---@nodiscard
function _colors.are_equal(c1, c2, tolerance)
	check_are_equal(c1, c2, tolerance)

	tolerance = tolerance or default_tolerance

	local n1 = normalize_color(c1)
	local n2 = normalize_color(c2)

	for _, channel in pairs({ "r", "g", "b", "a" }) do
		if math.abs(n1[channel] - n2[channel]) > tolerance then
			return false
		end
	end

	return true
end

---A validator that checks that a value is an 8-character ARGB hex code, such as `"FF00C1DF"`.
local argb_hex = V.string()
	:matches("^%x%x%x%x%x%x%x%x$", "eight hexadecimal digits, in the order alpha, red, green, and blue")
	:describe_as("an ARGB hex code")

local check_from_argb = V.signature("from_argb", {
	{ "hex", argb_hex },
})

---Converts an ARGB hex code to an RGBA color vector compatible with Factorio prototypes.
---
---This method is to facilitate compatibility between the [Factorio Modding Tool Kit](https://marketplace.visualstudio.com/items?itemName=justarandomgeek.factoriomod-debug)
---and Visual Studio Code's native color picker in a lua workspace. Leading hash (`"#"`) characters are not supported;
---
---Visual Studio Code will remove them anyways on interacting with the color picker.
---
---Use anywhere you would use a tint.
---@param hex string An 8-character ARGB color hex code.
---@return Color # The color the hex code names.
---
---#### Examples
---Import the colors module and then use it to create a tint. If working with the Factorio Modding Tool Kit and Visual
---Studio Code, once the Lua workspace has loaded the color picker will be interactive and render correctly in game.
---```lua
---local colors = require("__reskins-sprites-utils__.colors")
---
---local tahiti_blue = colors.from_argb("FF00C1DF")
---```
---@throws Thrown when `hex` is `nil`.
---@throws Thrown when `hex` is not eight hexadecimal digits.
---@deprecated Use util.color("RRGGBBAA") with latest versions of FTMK/EmmyLua, as the color picker now correctly maintains RGBA syntax.
---@nodiscard
function _colors.from_argb(hex)
	check_from_argb(hex)

	return util.color(hex:sub(3, 8) .. hex:sub(1, 2)) --[[@as Color]]
end

-- The following functions are adapted from work done by Maxreader, and implement the formulas for HSV/HSL to RGB and
-- vice versa from https://en.wikipedia.org/wiki/HSL_and_HSV

local check_rgba_to_hsva = V.signature("rgba_to_hsva", {
	{ "tint", Common.color },
})

---
---Converts the provided `tint` from RGBA to HSVA color space.
---
---`tint` is not required to be normalized beforehand.
---
---#### Parameters
---@param tint Color The RGBA color to convert.
---
---#### Returns
---@return HsvColor # An HSVA color with `h` in degrees (0–360) and `s`, `v`, `a` between 0 and 1.
---
---#### Examples
---```lua
---local hsva = _colors.rgba_to_hsva({ r = 0, g = 0.753, b = 0.871, a = 1 })
---```
---@throws Thrown when `tint` is `nil`.
---@throws Thrown when `tint` is not a `Color`.
---@nodiscard
function _colors.rgba_to_hsva(tint)
	check_rgba_to_hsva(tint)

	local n = normalize_color(tint)
	local r, g, b, a = n.r, n.g, n.b, n.a

	local max = math.max(r, g, b)
	local min = math.min(r, g, b)
	local range = max - min

	local h = 0.0
	if range == 0 then
		h = 0
	elseif max == r then
		h = (g - b) / range * 60
	elseif max == g then
		h = (2 + (b - r) / range) * 60
	elseif max == b then
		h = (4 + (r - g) / range) * 60
	end

	if h < 0 then
		h = h + 360
	end

	local v = max

	-- Black has zero saturation. Dividing by zero would yield NaN.
	local s = 0.0
	if max > 0 then
		s = range / max
	end

	return {
		h = h,
		s = s,
		v = v,
		a = a,
	}
end

local check_rgba_to_hsla = V.signature("rgba_to_hsla", {
	{ "tint", Common.color },
})

---
---Converts the provided `tint` from RGBA to HSLA color space.
---
---`tint` is not required to be normalized beforehand.
---
---#### Parameters
---@param tint Color The RGBA color to convert.
---
---#### Returns
---@return HslColor # An HSLA color with `h` in degrees (0–360) and `s`, `l`, `a` between 0 and 1.
---
---#### Examples
---```lua
---local hsla = _colors.rgba_to_hsla({ r = 0, g = 0.753, b = 0.871, a = 1 })
---```
---@throws Thrown when `tint` is `nil`.
---@throws Thrown when `tint` is not a `Color`.
---@nodiscard
function _colors.rgba_to_hsla(tint)
	check_rgba_to_hsla(tint)

	local n = normalize_color(tint)
	local r, g, b, a = n.r, n.g, n.b, n.a

	local max = math.max(r, g, b)
	local min = math.min(r, g, b)
	local range = max - min

	local h = 0.0
	if max == min then
		h = 0
	elseif max == r then
		h = (g - b) / range * 60
	elseif max == g then
		h = (2 + (b - r) / range) * 60
	elseif max == b then
		h = (4 + (r - g) / range) * 60
	end

	if h < 0 then
		h = h + 360
	end

	local l = (min + max) / 2
	local s = 0.0

	if not (min == 1 or max == 0) then
		s = (max - l) / math.min(l, 1 - l)
	end

	return {
		h = h,
		s = s,
		l = l,
		a = a,
	}
end

local check_hsva_to_rgba = V.signature("hsva_to_rgba", {
	{ "tint", Common.hsv_color },
})

---
---Converts the provided `tint` from HSVA to RGBA color space.
---
---#### Parameters
---@param tint HsvColor The HSVA color to convert, with `h` in degrees (0–360) and `s`, `v`, `a` between 0 and 1.
---
---#### Returns
---@return NormalizedColor # An RGBA color with channel values clamped between 0 and 1.
---
---#### Examples
---```lua
---local rgba = _colors.hsva_to_rgba({ h = 191, s = 1, v = 0.871, a = 1 })
---```
---@throws Thrown when `tint` is `nil`.
---@throws Thrown when `tint` is not an `HsvColor`.
---@throws Thrown when `tint.s`, `tint.v`, or `tint.a` is not between 0 and 1.
---@nodiscard
function _colors.hsva_to_rgba(tint)
	check_hsva_to_rgba(tint)

	local h, s, v, a = tint.h, tint.s, tint.v, tint.a

	local function f(n)
		local k = (n + h / 60) % 6
		return v - v * s * math.max(math.min(k, 4 - k, 1), 0)
	end
	return {
		r = clamp(f(5)),
		g = clamp(f(3)),
		b = clamp(f(1)),
		a = clamp(a),
	}
end

local check_hsla_to_rgba = V.signature("hsla_to_rgba", {
	{ "tint", Common.hsl_color },
})

---
---Converts the provided `tint` from HSLA to RGBA color space.
---
---#### Parameters
---@param tint HslColor The HSLA color to convert, with `h` in degrees (0–360) and `s`, `l`, `a` between 0 and 1.
---
---#### Returns
---@return NormalizedColor # An RGBA color with channel values clamped between 0 and 1.
---
---#### Examples
---```lua
---local rgba = _colors.hsla_to_rgba({ h = 191, s = 1, l = 0.435, a = 1 })
---```
---@throws Thrown when `tint` is `nil`.
---@throws Thrown when `tint` is not an `HslColor`.
---@throws Thrown when `tint.s`, `tint.l`, or `tint.a` is not between 0 and 1.
---@nodiscard
function _colors.hsla_to_rgba(tint)
	check_hsla_to_rgba(tint)

	local h, s, l, a = tint.h, tint.s, tint.l, tint.a

	local function f(n)
		local k = (n + h / 30) % 12
		local x = s * math.min(l, 1 - l)
		return l - x * math.max(math.min(k - 3, 9 - k, 1), -1)
	end

	return {
		r = clamp(f(0)),
		g = clamp(f(8)),
		b = clamp(f(4)),
		a = clamp(a),
	}
end

local function srgb_to_linear(channel)
	if channel <= 0.04045 then
		return channel / 12.92
	else
		return ((channel + 0.055) / 1.055) ^ 2.4
	end
end

local function linear_to_srgb(channel)
	channel = math.max(0, math.min(1, channel))
	if channel <= 0.0031308 then
		return 12.92 * channel
	else
		return 1.055 * channel ^ (1 / 2.4) - 0.055
	end
end

local check_overlay = V.signature("overlay", {
	{ "base", Common.color },
	{ "overlay", Common.color },
})

---
---Simulates placing a semi-transparent `overlay` color on top of a `base` color using
---alpha compositing in linear light (sRGB gamma).
---
---`base` and `overlay` are not required to be normalized beforehand.
---
---#### Parameters
---@param base Color The base color to composite over.
---@param overlay Color The overlay color to composite on top.
---
---#### Returns
---@return NormalizedColor # The composited RGBA color, with channel values clamped between 0 and 1.
---
---#### Examples
---```lua
---local result = _colors.overlay(
---    { r = 0.2, g = 0.2, b = 0.2, a = 1 },
---    { r = 0, g = 0.753, b = 0.871, a = 0.5 }
---)
---```
---@throws Thrown when `base` or `overlay` is `nil`.
---@throws Thrown when `base` or `overlay` is not a `Color`.
---@nodiscard
function _colors.overlay(base, overlay)
	check_overlay(base, overlay)

	local b = normalize_color(base)
	local o = normalize_color(overlay)

	local result = {}
	for _, c in pairs({ "r", "g", "b" }) do
		local b_lin = srgb_to_linear(b[c])
		local o_lin = srgb_to_linear(o[c])

		result[c] = clamp(linear_to_srgb(o_lin * o.a + b_lin * (1 - o.a)))
	end
	result.a = clamp(o.a + b.a * (1 - o.a))
	return result --[[@as NormalizedColor]]
end

---@param r float
---@param g float
---@param b float
---@return float
---@return float
---@return float
local function linear_rgb_to_oklab(r, g, b)
	local l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ^ (1 / 3)
	local m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ^ (1 / 3)
	local s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ^ (1 / 3)

	return 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
end

---@param L float
---@param a float
---@param b float
---@return float
---@return float
---@return float
local function oklab_to_linear_rgb(L, a, b)
	local l = (L + 0.3963377774 * a + 0.2158037573 * b) ^ 3
	local m = (L - 0.1055613458 * a - 0.0638541728 * b) ^ 3
	local s = (L - 0.0894841775 * a - 1.2914855480 * b) ^ 3

	return 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.6076099658 * s
end

local check_blend = V.signature("blend", {
	{ "c1", Common.color },
	{ "c2", Common.color },
	{ "weight", Common.unit_interval:optional() },
})

---
---Blends the provided colors `c1` and `c2` uniformly in perceptual color space
---using the provided `weight`, using Oklab.
---
---`c1` and `c2` are not required to be normalized beforehand.
---
---#### Parameters
---@param c1 Color The first color.
---@param c2 Color The second color.
---@param weight? float A fractional weight between 0 and 1 that determines the proportional color mix. When `0`, `c1` is returned, when `1`, `c2` is returned. Default `0.5`.
---
---#### Returns
---@return NormalizedColor # The blended RGBA color, with channel values clamped between 0 and 1.
---
---#### Examples
---```lua
---local blended = _colors.blend(
---    { r = 1, g = 0, b = 0, a = 1 },
---    { r = 0, g = 0, b = 1, a = 1 },
---    0.5
---)
---```
---@throws Thrown when `c1` or `c2` is `nil`.
---@throws Thrown when `c1` or `c2` is not a `Color`.
---@throws Thrown when `weight` is not between 0 and 1.
---@nodiscard
function _colors.blend(c1, c2, weight)
	check_blend(c1, c2, weight)

	if weight == 0 then
		return normalize_color(c1)
	elseif weight == 1 then
		return normalize_color(c2)
	end

	weight = weight or 0.5
	local nc1 = normalize_color(c1)
	local nc2 = normalize_color(c2)

	local r1, g1, b1 = srgb_to_linear(nc1.r), srgb_to_linear(nc1.g), srgb_to_linear(nc1.b)
	local r2, g2, b2 = srgb_to_linear(nc2.r), srgb_to_linear(nc2.g), srgb_to_linear(nc2.b)
	local L1, a1, b1_ = linear_rgb_to_oklab(r1, g1, b1)
	local L2, a2, b2_ = linear_rgb_to_oklab(r2, g2, b2)
	local Lm = L1 + (L2 - L1) * weight
	local am = a1 + (a2 - a1) * weight
	local bm = b1_ + (b2_ - b1_) * weight
	local r, g, b = oklab_to_linear_rgb(Lm, am, bm)
	return {
		r = clamp(linear_to_srgb(r)),
		g = clamp(linear_to_srgb(g)),
		b = clamp(linear_to_srgb(b)),
		a = clamp(nc1.a + (nc2.a - nc1.a) * weight),
	}
end

return _colors
