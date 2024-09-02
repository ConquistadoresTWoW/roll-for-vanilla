local modules = LibStub( "RollFor-Modules" )
if modules.SoftResCheck then return end

local M = {}

local filter = modules.filter
local negate = modules.negate
local colors = modules.colors
local pretty_print = function( text ) modules.pretty_print( text, colors.softres ) end

---@diagnostic disable-next-line: deprecated
local getn = table.getn

local ResultType = {
  NoItemsFound = "NoItemsFound",
  SomeoneIsNotSoftRessing = "SomeoneIsNotSoftRessing",
  FoundOutdatedData = "FoundOutdatedData",
  Ok = "Ok"
}

local function show( players )
  local p = function( text ) modules.pretty_print( text, colors.orange ) end
  p( "Players who did not soft-res:" )

  local buffer = ""

  for i = 1, getn( players ) do
    local separator = ""

    if buffer ~= "" then
      separator = separator .. ", "
    end

    local next = colors.hl( players[ i ].name )

    if string.len( buffer .. separator .. next ) > 255 then
      p( buffer )
      buffer = next
    else
      buffer = buffer .. separator .. next
    end
  end

  if buffer ~= "" then
    p( buffer )
  end
end

function M.new( softres, group_roster, name_matcher, ace_timer, absent_softres, db )
  local refetch_retries = 0

  local function show_who_is_not_softressing( silent )
    local players = group_roster.get_all_players_in_my_group()
    local not_softressing = filter( players,
      negate( function( player )
        return softres.is_player_softressing( player.name )
      end
      ) )

    if getn( not_softressing ) == 0 then
      if silent ~= true then modules.pretty_print( "All players in the group are soft-ressing.", colors.green ) end
      return ResultType.Ok
    end

    if silent ~= true then show( not_softressing ) end
    return ResultType.SomeoneIsNotSoftRessing, not_softressing
  end

  local function check_softres( silent )
    local timestamp = db.char.softres_import_timestamp

    if timestamp and modules.lua.time() - timestamp > 6 * 3600 then
      return ResultType.FoundOutdatedData
    end

    local softres_players = softres.get_all_softres_player_names()

    if getn( softres_players ) == 0 then
      if silent ~= true then pretty_print( "No soft-res items found." ) end
      return ResultType.NoItemsFound
    end

    if silent ~= true then modules.NameMatchReport.report( name_matcher ) end
    return show_who_is_not_softressing( silent )
  end

  local function show_softres( retry )
    if not retry then refetch_retries = 0 else refetch_retries = refetch_retries + 1 end

    local needs_refetch = false
    local softressed_item_ids = softres.get_item_ids()
    local items = {}
    local unavailable_items = {}

    local p = pretty_print

    for _, item_id in pairs( softressed_item_ids ) do
      local players = softres.get( item_id )
      local quality = softres.get_item_quality( item_id )
      local item_link = modules.fetch_item_link( item_id, quality )

      if not item_link and refetch_retries < 3 then
        modules.set_game_tooltip_with_item_id( item_id )
        needs_refetch = true
      elseif not item_link then
        unavailable_items[ item_id ] = players
      else
        items[ item_link ] = players
      end
    end

    if needs_refetch then
      modules.pretty_print( "Fetching soft-ressed items details from the server...", colors.grey )
      refetch_retries = refetch_retries + 1
      ace_timer.ScheduleTimer( M, function() show_softres( true ) end, 1 )
      return
    end

    local absent_softres_players = absent_softres( softres ).get_all_softres_player_names()

    local item_count = modules.count_elements( items )
    local unavailable_item_count = modules.count_elements( unavailable_items )

    if item_count == 0 and unavailable_item_count == 0 then
      p( "No soft-res items found." )
      return
    end

    modules.NameMatchReport.report( name_matcher )

    local colorize = function( player )
      local c = group_roster.is_player_in_my_group( player.name ) and colors.white or colors.red
      return player.rolls > 1 and string.format( "%s (%s)", c( player.name ), player.rolls ) or string.format( "%s", c( player.name ) )
    end

    if item_count > 0 then
      p( string.format( "Soft-ressed items%s:",
        getn( absent_softres_players ) > 0 and string.format( " (players in %s are not in your group)", colors.red( "red" ) ) or "" ) )

      for item_link, players in pairs( items ) do
        if modules.count_elements( players ) > 0 then
          p( string.format( "%s: %s", item_link, modules.prettify_table( players, colorize ) ) )
        end
      end
    end

    if unavailable_item_count > 0 then
      p( string.format( "Unavailable soft-ressed items%s:",
        getn( absent_softres_players ) > 0 and string.format( " (players in %s are not in your group)", colors.red( "red" ) ) or "" ) )

      for item_id, players in pairs( unavailable_items ) do
        if modules.count_elements( players ) > 0 then
          p( string.format( "%s: %s", item_id, modules.prettify_table( players, colorize ) ) )
        end
      end
    end

    show_who_is_not_softressing()
  end

  local function warn_if_no_data()
    local result = check_softres( true )

    if result == ResultType.SomeoneIsNotSoftRessing then
      check_softres()
    elseif result == ResultType.NoItemsFound then
      modules.pretty_print( "No softres items found." )
    elseif result == ResultType.FoundOutdatedData then
      modules.pretty_print( "Found outdated softres data.", modules.colors.red )
    end
  end

  return {
    check_softres = check_softres,
    show_softres = show_softres,
    show_who_is_not_softressing = show_who_is_not_softressing,
    warn_if_no_data = warn_if_no_data,
    ResultType = ResultType
  }
end

modules.SoftResCheck = M
return M
