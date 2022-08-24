-- Testing
-- * run test in the project root, `DESC` is optional:
--   * nvim -u NONE --headless -c ":luafile tests/init.lua" +quit
--   * DESC=1 nvim -u NONE --headless -c ":luafile tests/init.lua" +quit
-- * add test:
--   1. append the file path to the path table
--   2. the testing file returns a table containing testing functions
--   3. testing functions takes an optional `desc` argument which tells the purpose of testing

local function test(path, desc)
  for name, fn in pairs(dofile(path)) do
    print(path, '::', name, '-- PASS --', fn(desc))
  end
end

local desc = os.getenv("DESC")
local path = {
  "tests/check_highlights.lua",
}

for _, p in ipairs(path) do
  test(p, desc)
end
