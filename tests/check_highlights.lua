-- local litee = require("../lua/litee/lib/")
local highlights = dofile("/root/.local/share/nvim/site/pack/packer/start/litee.nvim/lua/litee/lib/highlights/init.lua")
local hls, dark, light = highlights.hls, highlights.dark, highlights.light
local M, dark_fields, light_fields = {}, {}, {}
for key, _ in pairs(dark) do
  dark_fields[key] = true
end
for key, _ in pairs(light) do
  light_fields[key] = true
end

function M.check_dark_light_fields(desc)
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

return M
