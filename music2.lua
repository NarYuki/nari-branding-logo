local api_base_url = "https://ipod-2to6magyna-uc.a.run.app/"

local width, height = term.getSize()

local tab = 1
local waiting_for_input = false
local last_search = nil
local last_search_url = nil
local search_results = nil
local search_error = false
local in_fullscreen = 0
local clicked_result = nil

local playing = false
local queue = {}
local now_playing = nil
local looping = false

local playing_id = nil
local last_download_url = nil
local playing_status = 0

local player_handle = nil
local start = nil
local pcm = nil
local size = nil
local decoder = nil
local needs_next_chunk = 0
local buffer

-- スピーカーの初期化（有線モデム対応）
local speakers = { peripheral.find("speaker") }
if #speakers == 0 then
    error("No speakers attached. Check your modems!", 0)
end
local speaker = speakers[1]
local speaker_name = peripheral.getName(speaker) -- ネットワーク上の名前を取得

os.startTimer(1)

local function redrawScreen()
    if waiting_for_input == true then
        return
    end

	term.setBackgroundColor(colors.black)
	term.clear()
	
	term.setCursorPos(1,1)
	term.setBackgroundColor(colors.gray)
	term.clearLine()
	
	local tabs = {" Now Playing ", " Search "}
	
	for i=1,2,1 do
		if tab == i then
			term.setTextColor(colors.black)
			term.setBackgroundColor(colors.white)
		else
			term.setTextColor(colors.white)
			term.setBackgroundColor(colors.gray)
		end
		
		term.setCursorPos((math.floor((width/2)*(i-0.5)))-math.ceil(#tabs[i]/2)+1, 1)
		term.write(tabs[i])
	end

    if tab == 1 then
        if now_playing ~= nil then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.setCursorPos(2,3)
            term.write(now_playing.name)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(2,4)
            term.write(now_playing.artist)
        else
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(2,3)
            term.write("Not playing")
        end

        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.gray)

        if playing then
            term.setCursorPos(2, 6)
            term.write(" Stop ")
        else
            term.setCursorPos(2, 6)
            term.write(" Play ")
        end

        term.setCursorPos(2 + 8, 6)
        term.write(" Skip ")

        if looping then
            term.setTextColor(colors.black)
            term.setBackgroundColor(colors.white)
        else
            term.setTextColor(colors.white)
            term.setBackgroundColor(colors.gray)
        end
        term.setCursorPos(2 + 8 + 8, 6)
        term.write(" Loop ")

        if #queue > 0 then
            term.setBackgroundColor(colors.black)
            for i=1,#queue do
                term.setTextColor(colors.white)
                term.setCursorPos(2,8 + (i-1)*2)
                term.write(queue[i].name)
                term.setTextColor(colors.lightGray)
                term.setCursorPos(2,9 + (i-1)*2)
                term.write(queue[i].artist)
            end
        end
    end
	
	if tab == 2 then
		for a=3,5,1 do
			term.setCursorPos(2,a)
			term.setTextColor(colors.lightGray)
			term.setBackgroundColor(colors.lightGray)
			for i=1,width-2,1 do
				term.write(" ")
			end
		end
		term.setCursorPos(3,4)
		term.setTextColor(colors.black)
		term.write(last_search or "Search...")

        if search_results ~= nil then
            term.setBackgroundColor(colors.black)
            for i=1,#search_results do
                term.setTextColor(colors.white)
                term.setCursorPos(2,7 + (i-1)*2)
                term.write(search_results[i].name)
                term.setTextColor(colors.lightGray)
                term.setCursorPos(2,8 + (i-1)*2)
                term.write(search_results[i].artist)
            end
        else
            term.setCursorPos(2,7)
            term.setBackgroundColor(colors.black)
            if search_error == true then
                term.setTextColor(colors.red)
                term.write("Error")
            elseif last_search_url ~= nil then
                term.setTextColor(colors.white)
                term.write("Searching...")
            end
        end

        if in_fullscreen == 1 then
            term.setBackgroundColor(colors.black)
            term.clear()
            term.setCursorPos(2,2)
            term.setTextColor(colors.white)
            term.write(search_results[clicked_result].name)
            term.setCursorPos(2,3)
            term.setTextColor(colors.lightGray)
            term.write(search_results[clicked_result].artist)

            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.white)

            term.setCursorPos(2,6)
            term.clearLine()
            term.write("Play now")

            term.setCursorPos(2,8)
            term.clearLine()
            term.write("Play next")

            term.setCursorPos(2,10)
            term.clearLine()
            term.write("Add to queue")

            term.setCursorPos(2,13)
            term.clearLine()
            term.write("Cancel")
        end
	end
end

local function searchInput()
    while true do
        if waiting_for_input == true then
            for a=3,5,1 do
                term.setCursorPos(2,a)
                term.setTextColor(colors.white)
                term.setBackgroundColor(colors.white)
                for i=1,width-2,1 do
                    term.write(" ")
                end
            end
            term.setCursorPos(3,4)
            term.setTextColor(colors.black)
            local input = read()
            if string.len(input) > 0 then
                last_search = input
                last_search_url = api_base_url .. "?search=" .. textutils.urlEncode(input)
                http.request(last_search_url)
                search_results = nil
                search_error = false
            else
                last_search = nil
                last_search_url = nil
                search_results = nil
                search_error = false
            end
            waiting_for_input = false
            redrawScreen()
        end
        sleep(0.1)
    end
end

local function mainLoop()
    redrawScreen()

    while true do
        if playing and now_playing then
            if playing_id ~= now_playing.id then
                playing_id = now_playing.id
                last_download_url = api_base_url .. "?id=" .. textutils.urlEncode(playing_id)
                playing_status = 0
                needs_next_chunk = 1
                http.request({url = last_download_url, binary = true})
                redrawScreen()
            end
            if playing_status == 1 and needs_next_chunk == 3 then
                needs_next_chunk = 1
                while not speaker.playAudio(buffer) do
                    needs_next_chunk = 2
                    break
                end
            end
            if playing_status == 1 and needs_next_chunk == 1 then
                while true do
                    local chunk = player_handle.read(size)
                    if not chunk then
                        if looping then
                            playing_id = nil
                        else
                            if #queue > 0 then
                                now_playing = queue[1]
                                table.remove(queue, 1)
                                playing_id = nil
                            else
                                now_playing = nil
                                playing = false
                                playing_id = nil
                            end
                        end
                        redrawScreen()
                        player_handle.close()
                        needs_next_chunk = 0
                        break
                    else
                        if start then
                            chunk, start = start .. chunk, nil
                            size = size + 4
                        end
                        buffer = decoder(chunk)
                        while not speaker.playAudio(buffer) do
                            needs_next_chunk = 2
                            break
                        end
                        if needs_next_chunk == 2 then
                            break
                        end
                    end
                end
            end
        end
        
        local event, param1, param2, param3 = os.pullEvent()	

        if event == "mouse_click" and waiting_for_input == false then
            local button, x, y = param1, param2, param3
            if button == 1 and in_fullscreen == 0 then
                if y == 1 then
                    tab = (x < width/2) and 1 or 2
                end
            end

            if in_fullscreen == 1 then
                if y == 6 then
                    in_fullscreen = 0
                    now_playing = search_results[clicked_result]
                    playing = true
                    playing_id = nil
                elseif y == 8 then
                    in_fullscreen = 0
                    table.insert(queue, 1, search_results[clicked_result])
                elseif y == 10 then
                    in_fullscreen = 0
                    table.insert(queue, search_results[clicked_result])
                elseif y == 13 then
                    in_fullscreen = 0
                end
            else
                if tab == 1 and button == 1 then
                    if y == 6 then
                        if x >= 2 and x <= 8 then
                            if playing then
                                playing = false
                                speaker.stop()
                                playing_id = nil
                            elseif now_playing or #queue > 0 then
                                if not now_playing then
                                    now_playing = queue[1]
                                    table.remove(queue, 1)
                                end
                                playing = true
                                playing_id = nil
                            end
                        elseif x >= 10 and x <= 16 then
                            speaker.stop()
                            if #queue > 0 then
                                now_playing = queue[1]
                                table.remove(queue, 1)
                                playing_id = nil
                            else
                                now_playing = nil
                                playing = false
                                playing_id = nil
                            end
                        elseif x >= 18 and x <= 24 then
                            looping = not looping
                        end
                    end
                elseif tab == 2 and button == 1 then
                    if y >= 3 and y <= 5 then
                        waiting_for_input = true
                    elseif search_results then
                        for i=1,#search_results do
                            if y == 7 + (i-1)*2 or y == 8 + (i-1)*2 then
                                in_fullscreen = 1
                                clicked_result = i
                            end
                        end
                    end
                end
            end
            redrawScreen()
        end

        if event == "http_success" then
            if param1 == last_search_url then
                search_results = textutils.unserialiseJSON(param2.readAll())
                redrawScreen()
            elseif param1 == last_download_url then
                player_handle = param2
                start = param2.read(4)
                size = 16 * 1024 - 4
                playing_status = 1
                decoder = require "cc.audio.dfpwm".make_decoder()
            end
        end

        if event == "http_failure" then
            if param1 == last_search_url then
                search_error = true
                redrawScreen()
            elseif param1 == last_download_url then
                if #queue > 0 then
                    now_playing = queue[1]
                    table.remove(queue, 1)
                else
                    now_playing = nil
                    playing = false
                end
                playing_id = nil
                redrawScreen()
            end
        end

        -- 有線モデム対応のイベント判別
        if event == "speaker_audio_empty" then
            if param1 == speaker_name then -- 自分のスピーカー名と一致する場合のみ処理
                if needs_next_chunk == 2 then
                    needs_next_chunk = 3
                end
            end
        end

        if event == "timer" then
            os.startTimer(1)
        end
    end
end

parallel.waitForAny(mainLoop, searchInput)