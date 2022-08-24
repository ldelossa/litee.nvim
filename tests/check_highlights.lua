local litee = "lua/litee/lib/"
local highlights = dofile(litee .. "highlights/init.lua")
local hls, dark, light = highlights.hls, highlights.dark, highlights.light
local M, dark_fields, light_fields = {}, {}, {}
for key, _ in pairs(dark) do
  dark_fields[key] = true
end
for key, _ in pairs(light) do
  light_fields[key] = true
end

function M.hls_dark(desc)
  for _, hl in pairs(hls) do
    assert(dark_fields[hl], "dark_feild lacks " .. hl)
  end
  if desc then
    return "The highlights in hls are all defined."
  end
end

function M.dark_light_fields(desc)
  for key, _ in pairs(dark_fields) do
    assert(light_fields[key], "light_feild lacks " .. key)
  end
  for key, _ in pairs(light_fields) do
    assert(dark_fields[key], "dark_feild lacks " .. key)
  end
  if desc then
    return "Fields are the same in light & dark highlights."
  end
end

function M.icon_hls(desc)
  local icons = dofile(litee .. "icons/init.lua")
  for _, hl in pairs(icons.icon_hls) do
    assert(dark_fields[hl], hl .. "is not defined.")
  end
  if desc then
    return "All highlights in icon_hls are defined."
  end
end

return M
