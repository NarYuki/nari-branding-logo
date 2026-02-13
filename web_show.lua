-- 画像表示プログラム (web_show.lua)
local args = { ... }
local url = args[1]
local monitorSide = args[2] or "top"

if not url then
    print("Usage: web_show <url> <side>")
    return
end

-- モニターの準備
if not peripheral.isPresent(monitorSide) then
    print("Error: Monitor not found on " .. monitorSide)
    return
end
local mon = peripheral.wrap(monitorSide)

-- 外部の画像変換サービスを利用するためのURL構築
-- (URLをエスケープして変換APIに投げる)
local apiUrl = "https://api.cloud-catch.com/image?url=" .. url .. "&format=nfp"

print("Downloading and converting image...")
local response = http.get(apiUrl)

if not response then
    print("Error: Could not connect to conversion API.")
    return
end

-- 取得したデータを一時ファイルとして保存
local imageContent = response.readAll()
response.close()

local tempFile = "temp_image.nfp"
local f = fs.open(tempFile, "w")
f.write(imageContent)
f.close()

-- 描画処理
local image = paintutils.loadImage(tempFile)
term.redirect(mon)
term.setBackgroundColor(colors.black)
term.clear()
paintutils.drawImage(image, 1, 1)
term.restore()

print("Success! Image displayed on " .. monitorSide)