--- @since 25.4.8
--- @sync seek -- Read skip state synchronously to prevent race conditions with rapid scroll events.

-- Configuration
local DEBUG = false  -- Set to `true` to enable debug messages (and run `YAZI_LOG=debug yazi`)

-- Helper function for debug logging (for visibility in logs)
local function debug_log(message)
  if DEBUG then
    -- Use ya.err for ; prefix makes it easy to grep
    ya.err("zless-preview: " .. message)
  end
end

local M = {}

function M:peek(job)
  debug_log("Entering peek function")
  local skip_val = job.skip or 0
  local area_h = job.area and job.area.h or 0
  debug_log("Preview for: " .. tostring(job.file.url) .. ", skip=" .. tostring(skip_val) .. ", area.h=" .. tostring(area_h))

  if not job.file or not job.file.url then
    debug_log("Error: Invalid file URL in peek")
    ya.preview_widgets(job, { ui.Text.parse("Error: Invalid file URL"):area(job.area) })
    return
  end

  -- Safely escape the path for shell execution
  local path_str = tostring(job.file.url)
  local safe_path = path_str:gsub("'", "'\\''")

  -- Use zless: -R for raw control chars (colors), -S to chop long lines.
  local cmd = string.format("zless -S -R '%s' 2>/dev/null", safe_path)
  debug_log("Running command: " .. cmd)

  local handle = io.popen(cmd, "r")
  if not handle then
    debug_log("Failed to open zless process")
    ya.preview_widgets(job, { ui.Text.parse("Error: Could not preview file with zless"):area(job.area) })
    return
  end

  -- Read incrementally up to the height of the preview area
  local limit = area_h
  local skip = skip_val
  local i, lines = 0, ""

  debug_log("Starting incremental read loop: skip=" .. skip .. ", limit=" .. limit)
  while true do
    local line = handle:read("*l")
    if not line then
      debug_log("EOF reached in zless output at line " .. i)
      break -- EOF
    end

    i = i + 1
    if i > skip then
      lines = lines .. line .. "\n"
      if i >= skip + limit then
        debug_log("Reached limit (" .. limit .. ") lines at line " .. i)
        break -- Reached preview limit
      end
    end
  end

  -- Close handle as soon as we have enough lines or hit EOF
  handle:close()
  debug_log(string.format("Read %d lines total (processed up to %d for display)", i, i - skip))

  if lines == "" then
    if skip > 0 then
      -- Attempted to skip past EOF, adjust skip and re-peek
      local actual_lines_in_file = i
      local new_skip = math.max(0, actual_lines_in_file - limit)
      debug_log("Empty output because skip (" .. skip .. ") > total lines (" .. actual_lines_in_file .. "). Resetting skip to " .. new_skip)
      ya.mgr_emit("peek", { new_skip, only_if = job.file.url })
    else
      -- File is actually empty or unreadable
      debug_log("File appears empty or unreadable by zless.")
      ya.preview_widgets(job, { ui.Text.parse("File is empty or not viewable with zless"):area(job.area) })
    end
  else
    -- Replace tabs with 4 spaces
    lines = lines:gsub("\t", string.rep(" ", 4))
    debug_log("Displaying content. First few chars: " .. lines:sub(1, 50))
    -- Display content, disabling Yazi's wrapping (since zless -S handles line chopping)
    ya.preview_widgets(job, { ui.Text.parse(lines):area(job.area):wrap(ui.Text.WRAP_NO) })

    -- If EOF was reached *before* filling the preview area, adjust skip
    -- This prevents overshooting when scrolling back up near the end.
    local lines_read_for_display = i - skip
    if lines_read_for_display < limit and skip > 0 and i < skip + limit then
       local actual_lines_in_file = i
       local new_skip = math.max(0, actual_lines_in_file - limit)
       debug_log(string.format("Reached end of file at line %d while reading. Adjusting skip to %d.", actual_lines_in_file, new_skip))
       ya.mgr_emit("peek", { new_skip, only_if = job.file.url })
    end
  end
  debug_log("Exiting peek function")
end

function M:seek(job)
  debug_log("Entering seek function (sync). job.units = " .. tostring(job.units))

  local current_skip = 0
  -- Ensure cx path exists before attempting access
  if cx and cx.active and cx.active.preview then
      current_skip = cx.active.preview.skip or 0
      debug_log("Read cx.active.preview.skip: " .. tostring(current_skip))
  else
      debug_log("Could not read cx.active.preview.skip, using fallback 0")
  end

  -- Calculate new skip value based on current state and requested units
  local new_skip = math.max(0, current_skip + job.units)

  debug_log(string.format("Calculated (from cx.skip): current_skip=%d, units=%d, new_skip=%d",
                          current_skip, job.units, new_skip))

  -- Emit peek event to trigger re-render with the new skip value
  -- Yazi core handles updating the internal state based on this event from sync context.
  debug_log("Emitting peek event with new_skip=" .. tostring(new_skip) .. " for file: " .. tostring(job.file.url))
  ya.mgr_emit("peek", { new_skip, only_if = job.file.url })
  debug_log("Exiting seek function")
end

return M

