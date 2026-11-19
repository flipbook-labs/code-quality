---
bump: minor
category: Features
kind: rules
---

Add the `roblox_incorrect_color3_new_bounds`, `roblox_manual_fromscale_or_fromoffset`, and `roblox_suspicious_udim2_new` lint rules, ported from Selene. They flag `Color3.new` values outside 0 to 1, `UDim2.new` calls that set only scale or only offset, and `UDim2.new` calls with one to three arguments.
