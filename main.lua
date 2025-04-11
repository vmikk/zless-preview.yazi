--- @since 25.4.8
--- @sync peek

-- Configuration
local DEBUG = false  -- Set to true to enable debug messages (and run `YAZI_LOG=debug yazi`)

-- Helper function for debug logging
local function debug_log(message)
  if DEBUG then
    ya.err(message)
  end
end

local M = {}

function M:peek(job)
  debug_log("Starting incremental preview for: " .. tostring(job.file.url))
  
  -- Make sure we have a valid file URL
  if not job.file or not job.file.url then
    ya.preview_widgets(job, { ui.Text.parse("Error: Invalid file URL"):area(job.area) })
    return
  end
  
  -- Safely escape the path
  local path_str = tostring(job.file.url)
  local safe_path = path_str:gsub("'", "'\\''")
  
  -- Use popen directly with zless for incremental reading
  local cmd = string.format("zless -S -R '%s' 2>/dev/null", safe_path)
  debug_log("Running command: " .. cmd)
  
  local handle = io.popen(cmd, "r")
  if not handle then
    debug_log("Failed to open zless process")
    ya.preview_widgets(job, { ui.Text.parse("Error: Could not preview file with zless"):area(job.area) })
    return
  end
  
  -- Read incrementally
  local limit = job.area.h
  local skip = job.skip or 0
  local i, lines = 0, ""
  
  -- Read line by line until we have enough
  while true do
    local line = handle:read("*l")
    if not line then 
      break 
    end
    
    i = i + 1
    if i > skip then
      lines = lines .. line .. "\n"
      -- Stop if we've read enough lines
      if i >= skip + limit then
        break
      end
    end
  end
  
  -- Close handle as soon as we have enough lines
  handle:close()
  
  debug_log(string.format("Read %d lines incrementally", i))
  
  if lines == "" then
    if skip > 0 then
      -- We tried to skip past the end of file, adjust and try again
      ya.manager_emit("peek", { skip = math.max(0, i - limit), only_if = job.file.url, upper_bound = true })
    else
      -- Empty file or error
      ya.preview_widgets(job, { ui.Text.parse("File is empty or not viewable with zless"):area(job.area) })
    end
  else
    -- Process and display content
    lines = lines:gsub("\t", string.rep(" ", 4))
    ya.preview_widgets(job, { ui.Text.parse(lines):area(job.area) })
  end
end

function M:seek(job)
  -- Calculate new skip value based on current skip and requested units
  local new_skip = math.max(0, job.skip + job.units)
  
  -- Emit a peek event with the updated skip value to redraw with new offset
  ya.manager_emit("peek", { skip = new_skip, only_if = job.file.url })
end

return M

