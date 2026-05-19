local M = {}

-- Die Mappings für other.nvim
M.mappings = {
  {
    pattern = "src/main/java/(.*)%.java$",
    target = "src/test/java/%1Test.java",
    context = "test",
  },
  {
    pattern = "src/test/java/(.*)Test%.java$",
    target = "src/main/java/%1.java",
    context = "source",
  },
}

-- Der Autocommand für die Template-Generierung
M.setup_autocmds = function()
  local java_template_grp = vim.api.nvim_create_augroup("JavaTestTemplateGroup", { clear = true })

  vim.api.nvim_create_autocmd("BufNewFile", {
    group = java_template_grp,
    pattern = "*/src/test/java/*Test.java",
    callback = function(args)
      local target_buf = args.buf
      local target_file = vim.api.nvim_buf_get_name(target_buf)
      local target_dir = vim.fn.fnamemodify(target_file, ":h")

      if vim.fn.isdirectory(target_dir) == 0 then vim.fn.mkdir(target_dir, "p") end

      local function find_and_read_build_files()
        local lines = {}
        local build_names = { "pom.xml", "build.gradle", "build.gradle.kts" }

        for _, name in ipairs(build_names) do
          if vim.fn.filereadable(name) == 1 then vim.list_extend(lines, vim.fn.readfile(name)) end
        end

        local loop_api = vim.uv or vim.loop
        local stop_dir = loop_api.cwd()
        local build_in_submodule = vim.fs.find(build_names, { path = target_dir, upward = true, stop = stop_dir })

        for _, file_path in ipairs(build_in_submodule) do
          if vim.fn.filereadable(file_path) == 1 then vim.list_extend(lines, vim.fn.readfile(file_path)) end
        end

        return lines
      end

      local content = find_and_read_build_files()
      local framework = "unknown"

      if #content > 0 then
        local has_testng = false
        local has_junit5 = false
        local has_junit4 = false

        for _, line in ipairs(content) do
          if line:find("testng", 1, true) then
            has_testng = true
          elseif
            line:find("junit-jupiter", 1, true)
            or line:find("org.junit.jupiter", 1, true)
            or line:find("junit5", 1, true)
          then
            has_junit5 = true
          elseif line:find("junit", 1, true) and not line:find("jupiter", 1, true) then
            has_junit4 = true
          end
        end

        if has_testng then
          framework = "testng"
        elseif has_junit5 then
          framework = "junit5"
        elseif has_junit4 then
          framework = "junit4"
        end
      end

      local package_path = target_file:match "src/test/java/(.-)/?[^/]+%.java$"
      local package_name = "package"
      if package_path and package_path ~= "" then package_name = package_path:gsub("/", ".") end

      local class_name = target_file:match "([^/]+)%.java$" or "TestClass"

      local templates = {
        junit5 = {
          "package " .. package_name .. ";",
          "",
          "import org.junit.jupiter.api.Test;",
          "import static org.junit.jupiter.api.Assertions.*;",
          "",
          "class " .. class_name .. " {",
          "",
          "    @Test",
          "    void shouldWork() {",
          "        // Generated with JUnit 5",
          "    }",
          "}",
        },
        junit4 = {
          "package " .. package_name .. ";",
          "",
          "import org.junit.Test;",
          "import static org.junit.Assert.*;",
          "",
          "public class " .. class_name .. " {",
          "",
          "    @Test",
          "    public void shouldWork() {",
          "        // Generated with JUnit 4",
          "    }",
          "}",
        },
        testng = {
          "package " .. package_name .. ";",
          "",
          "import org.testng.annotations.Test;",
          "import org.testng.Assert;",
          "",
          "public class " .. class_name .. " {",
          "",
          "    @Test",
          "    public void shouldWork() {",
          "        // Generated with TestNG",
          "    }",
          "}",
        },
        unknown = {
          "package " .. package_name .. ";",
          "",
          "/*",
          " * WARNING: No matching test framework (JUnit4, JUnit5, TestNG) was detected",
          " * in the root or submodule build configuration files.",
          " * Please verify your dependencies.",
          " */",
          "public class " .. class_name .. " {",
          "",
          "    @UnknownTestFramework",
          "    public void shouldWork() {",
          "        // TODO: Add test framework dependency and fix annotation",
          "    }",
          "}",
        },
      }

      local lines_to_write = templates[framework] or templates["unknown"]
      vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, lines_to_write)
    end,
  })
end

return M
