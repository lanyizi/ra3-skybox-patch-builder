#Requires -Version 2

if ($PSCommandPath -eq $Null) {
    $PSCommandPath = $MyInvocation.MyCommand.Definition
}

if ($PSScriptRoot -eq $Null) {
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

### 编译步骤
$global:willClearBuiltDirectory = $True
$global:willGenerateCubeMap = $True
$global:willCompilePatch = $True
$global:willCompilePatchLodLevels = $True
$global:willCopyAdditionalFiles = $True
$global:willCreateBigFile = $True

### 各种参数
# 工具路径
$global:htmlPath = Join-Path (Join-Path $PSScriptRoot "panorama-to-cubemap") "index.html"
$global:cmftPath = Join-Path (Join-Path $PSScriptRoot "cmft") "cmftRelease.exe"
$global:wrathEdPath = Join-Path (Join-Path $PSScriptRoot "WrathEdDebug") "WrathEd.exe"

# 文件夹路径
$global:patchDirectory = Join-Path $PSScriptRoot "static-patch"
$global:additionalFilesDirectory = Join-Path $patchDirectory "additional"
$global:generatedDirectory = Join-Path $patchDirectory "generated"
$global:builtDirectory = Join-Path $patchDirectory "built"
$global:basePatchStreamDirectory = Join-Path $patchDirectory "base-patch-streams"

# 最终生成的 BIG 文件一开始存放的路径
$global:outputDirectory = Join-Path $PSScriptRoot "output"
$global:outputBigPath = Join-Path $outputDirectory "Skybox.big"

# WED 编译参数
$global:inputXml = Join-Path $patchDirectory "static.xml"
$global:newStreamVersion = ".sky"
$global:basePatchStreamName = "static.12.manifest"

# 自动生成的天空盒贴图
$global:outputCubeMap = Join-Path $generatedDirectory "skybox"
$global:skyboxXml = "$outputCubeMap.xml"
$global:skyboxXmlContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<AssetDeclaration xmlns="uri:ea.com:eala:asset" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
	<Includes>
	</Includes>
	<Texture id="EVDefault" File="skybox.dds" Type="CubeTexture" />
</AssetDeclaration>
"@

### UI 文本
$global:mainTitle = "RAAA 天空盒补丁生成器"
$global:mainDescription = @"
岚依的天空盒补丁生成器，应该能兼容大部分 mod（
需要一些最基本的 RA3 Mod 知识（比如说如何让游戏或者 Mod 加载一个 BIG 文件之类的）
使用方法：
首先，点击 “创建十字贴图文件”，来把一个 2:1 的贴图转换成十字贴图。
接着，点击 “创建天空盒补丁”，这将会弹出一个窗口用来选择之前创建的十字贴图文件。
那么，只要选择了正确的文件，就能生成天空盒补丁了（
"@
$global:cancelDescription = "假如生成天空盒贴图的时间过长的话，可以考虑点击`“取消`”按钮然后重试一次"
$global:htmlButtonText = "创建十字贴图文件"
$global:compileButtonText = "创建天空盒补丁"
$global:cancelButtonText = "取消"
$global:showAdvancedButtonText = "显示高级选项"
$global:hideAdvancedButtonText = "隐藏高级选项"
$global:compilePatchText = "编译补丁"
$global:compilePatchLodLevelsText = "编译中低画质补丁"
$global:basePatchStreamDescription = "基于此 manifest 创建补丁"
$global:newStreamVersionText = "新的 manifest 版本号"
$global:editThisScriptText = @"
假如要进一步修改，可以考虑直接修改
<Hyperlink x:Name="ThisScriptLink" NavigateUri="$PSCommandPath">
    $((Get-Item $PSCommandPath).Name)
</Hyperlink>
脚本文件（可以直接用记事本打开；修改后需要重启 $mainTitle）
"@
$global:statusMessage = "正在{0}"
$global:statusFailedMessage = "{0}失败"
$global:clearBuiltDirectoryStatus = "清除上一次编译的文件"
$global:generateCubeMapStatus = "处理天空盒贴图"
$global:wedStatus = "编译"
$global:copyAdditionalFilesStatus = "复制额外文件"
$global:createBigFileStatus = "创建 BIG 文件"
$global:emptyBigMessage = "没有任何文件能被添加到 BIG 里，可能是哪些其他地方出了问题"
$global:saveFailedMessage = "保存 BIG 文件失败：{0}"
$global:chooseSkyboxTextureTitle = "选择天空盒贴图"
$global:skyboxTextureFilter = "天空盒贴图（*.png;*.tga;*.jpg;*.bmp;*.dds;*.hdr）|*.png;*.tga;*.jpg;*.bmp;*.dds;*.hdr|所有文件（*.*）|*.*"
$global:saveBigFileTitle = "保存 BIG 文件"
$global:bigFileFilter = "BIG 文件（*.big）|*.big|所有文件（*.*）|*.*"
$global:creditsText = @"
<Hyperlink NavigateUri="https://github.com/lanyizi/ra3-skybox-patch-builder">
    $mainTitle
</Hyperlink> v0.1
<LineBreak />
这个生成器使用了
<Hyperlink NavigateUri="https://github.com/lanyizi/panorama-to-cubemap">
    panorama-to-cubemap
</Hyperlink>、<Hyperlink NavigateUri="https://github.com/dariomanesku/cmft">
    cmft
</Hyperlink> 以及
<Hyperlink NavigateUri="https://github.com/Qibbi/WrathEd2012">
    WrathEd
</Hyperlink> 等工具
"@

$xaml = [xml]@"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    x:Name="Window" Title="$mainTitle" Width="360" Height="400">
    <ScrollViewer Margin="0" VerticalScrollBarVisibility="Auto">
        <StackPanel Orientation="Vertical" Margin="8">
            <TextBlock x:Name="MainDescription" Margin="4" TextWrapping="Wrap" />
            <Button x:Name="HtmlButton"
                Margin="4" HorizontalAlignment="Left"
                Content="$htmlButtonText"
            />
            <Button x:Name="CompileButton"
                Margin="4" HorizontalAlignment="Left"
                Content="$compileButtonText"
            />
            <Button x:Name="CancelButton"
                Margin="4" HorizontalAlignment="Left" Visibility="Collapsed"
                Content="$cancelButtonText"
            />
            <TextBlock x:Name="CancelDescription" Margin="4" TextWrapping="Wrap" Visibility="Collapsed" />
            <TextBlock x:Name="StatusDescription" Margin="4" TextWrapping="Wrap">
                $creditsText
            </TextBlock>
            <Button x:Name="ToggleAdvancedButton"
                Margin="4,8,4,4" HorizontalAlignment="Left"
                Content="$showAdvancedButtonText"
            />
            <StackPanel x:Name="AdvancedPanel" Orientation="Vertical" Margin="4" Visibility="Collapsed">
                <TextBlock Margin="4" TextWrapping="Wrap">
                    $editThisScriptText
                </TextBlock>
                <CheckBox x:Name="ToggleClearBuiltDirectory" 
                    Margin="4" HorizontalAlignment="Left" Content="$clearBuiltDirectoryStatus" 
                />
                <CheckBox x:Name="ToggleGenerateCubeMap" 
                    Margin="4" HorizontalAlignment="Left" Content="$generateCubeMapStatus" 
                />
                <CheckBox x:Name="ToggleCompilePatch" 
                    Margin="4" HorizontalAlignment="Left" Content="$compilePatchText" 
                />
                <CheckBox x:Name="ToggleCompilePatchLodLevels" 
                    Margin="4" HorizontalAlignment="Left" Content="$compilePatchLodLevelsText" 
                />
                <CheckBox x:Name="ToggleCopyAdditionalFiles" 
                    Margin="4" HorizontalAlignment="Left" Content="$copyAdditionalFilesStatus" 
                />
                <CheckBox x:Name="ToggleCreateBigFile" 
                    Margin="4" HorizontalAlignment="Left" Content="$createBigFileStatus" 
                />
                <Label Margin="4,8,4,0" HorizontalAlignment="Left" Content="$basePatchStreamDescription" />
                <TextBox x:Name="BasePatchStreamNameInput" Margin="12,0" />
                <Label Margin="4,8,4,0" HorizontalAlignment="Left" Content="$newStreamVersionText" />
                <TextBox x:Name="NewStreamVersionInput" Margin="12,0" />
            </StackPanel>
        </StackPanel>
    </ScrollViewer>
</Window>
"@

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
[Windows.Forms.Application]::EnableVisualStyles()

function Initialize-Wpf($window, $nativeWindow) {
    $window.Add_SourceInitialized({
        # 用于获取窗口的原生句柄
        $interopHelper = New-Object Windows.Interop.WindowInteropHelper -ArgumentList $window
        $nativeWindow.AssignHandle($interopHelper.Handle)
    }.GetNewClosure())

    # 添加超链接的点击支持，以及对勾选框的支持
    $window.Add_Loaded({
        function Add-HyperlinkEventHandler($owner) {
            $count = [Windows.Media.VisualTreeHelper]::GetChildrenCount($owner)
            for ($i = 0; $i -lt $count; $i = $i + 1) {
                $child = [Windows.Media.VisualTreeHelper]::GetChild($owner, $i);
                if ($child -eq $null) {
                    continue
                }
                if ($child.GetType().Equals([Windows.Controls.TextBlock])) {
                    foreach ($inline in $child.Inlines) {
                        if ($inline.GetType().Equals([Windows.Documents.Hyperlink])) {
                            $inline.Add_RequestNavigate({ 
                                param ($sender, $e)
                                if ($e.Uri.IsFile) {
                                    explorer.exe "/select,`"$($e.Uri.LocalPath)`""
                                }
                                else {
                                    Start-Process $e.Uri
                                }
                            })
                        }
                    }
                }
                if ($child.GetType().Equals([Windows.Controls.CheckBox])) {
                    $varname = $child.Name.Replace("Toggle", "will")
                    $variable = Get-Variable $varname -Scope Global
                    $child.IsChecked = $variable.Value
                    $child.Add_Click({ 
                        $variable.Value = ($child.IsChecked -eq $True) 
                    }.GetNewClosure())
                }
                Add-HyperlinkEventHandler $child
            }
        }
        Add-HyperlinkEventHandler $window
    }.GetNewClosure())

    $window.FindName("MainDescription").Text = $mainDescription
    $window.FindName("CancelDescription").Text = $cancelDescription
    $htmlButton = $window.FindName("HtmlButton")
    $compileButton = $window.FindName("CompileButton")
    $cancelButton = $window.FindName("CancelButton")
    $cancelDescription = $window.FindName("CancelDescription")
    $statusDescription = $window.FindName("StatusDescription")
    $toggleAdvancedButton = $window.FindName("ToggleAdvancedButton")
    $advancedPanel = $window.FindName("AdvancedPanel")
    $basePatchStreamNameInput = $window.FindName("BasePatchStreamNameInput")
    $newStreamVersionInput = $window.FindName("NewStreamVersionInput")

    $context = @{
        NativeWindow = $nativeWindow
    }

    $currentlyTrackedProcesses = New-Object Collections.Generic.List[object]
    $context.ChangeTrackedProcesses = {
        param ($newValues)

        if ($newValues -eq $Null) {
            $currentlyTrackedProcesses.Clear()
        }
        else {
            foreach ($process in $newValues) {
                $currentlyTrackedProcesses.Add($process)
            }
        }
        if ($currentlyTrackedProcesses.Count -gt 0) {
            $cancelButton.Visibility = [Windows.Visibility]::Visible
        }
        else {
            $cancelButton.Visibility = [Windows.Visibility]::Collapsed
        }
    }.GetNewClosure()
    & $context.ChangeTrackedProcesses $Null

    $context.SetStatus = {
        param ($statusText)
        $context.StatusText = $statusText
        $statusDescription.Text = [string]::Format($statusMessage, $context.StatusText)
        $statusDescription = [Windows.Visibility]::Visible
    }.GetNewClosure()

    $context.Complete = {
        param ($succeeded)
        $statusDescription.Text = ""
        $compileButton.IsEnabled = $True
        $advancedPanel.IsEnabled = $True
        if (-not $succeeded) {
            # 假如是由用户自己取消的 那就不需要下面的弹框报错了
            if (-not $context.IsCancelled) {
                $what = [string]::Format($statusFailedMessage, $context.StatusText)
                [Windows.Forms.MessageBox]::Show($what, $mainTitle)
            }
        }
    }.GetNewClosure()

    $htmlButton.Add_Click({
        & $htmlPath
    })

    $compileButton.Add_Click({
        $compileButton.IsEnabled = $False
        $advancedPanel.IsEnabled = $False
        $context.IsCancelled = $False
        Start-PatchBuild $context $compileButton.Dispatcher
    }.GetNewClosure())

    $cancelButton.Add_Click({
        foreach ($process in $currentlyTrackedProcesses) {
            $process.Kill()
        }
        $context.IsCancelled = $True
        & $context.ChangeTrackedProcesses $Null
    }.GetNewClosure())

    $toggleAdvancedButton.Add_Click({
        if ($advancedPanel.Visibility -eq [Windows.Visibility]::Visible) {
            $advancedPanel.Visibility = [Windows.Visibility]::Collapsed
            $toggleAdvancedButton.Content = $showAdvancedButtonText
        }
        else {
            $advancedPanel.Visibility = [Windows.Visibility]::Visible
            $toggleAdvancedButton.Content = $hideAdvancedButtonText
        }
    }.GetNewClosure())

    $basePatchStreamNameInput.Text = $basePatchStreamName
    $basePatchStreamNameInput.Add_TextChanged({
        (Get-Variable "basePatchStreamName" -Scope Global).Value = $basePatchStreamNameInput.Text
    }.GetNewClosure())

    $newStreamVersionInput.Text = $newStreamVersion
    $newStreamVersionInput.Add_TextChanged({
        (Get-Variable "newStreamVersion" -Scope Global).Value = $newStreamVersionInput.Text
    }.GetNewClosure())

    $context.ShowCancelText = { $cancelDescription.Visibility = [Windows.Visibility]::Visible }.GetNewClosure()
    $context.HideCancelText = { $cancelDescription.Visibility = [Windows.Visibility]::Collapsed }.GetNewClosure()
}

function global:Start-PatchBuild($context, $dispatcher) {

    $context.DoEvents = {
        # 能让程序在阻塞的时候仍然能更新一下文本之类的
        $dispatcher.Invoke([Windows.Threading.DispatcherPriority]::Background, [Action]{});
    }.GetNewClosure()

    $context.SynchronizationContext = New-Object Windows.Threading.DispatcherSynchronizationContext -ArgumentList $dispatcher

    # 用于清空暂存文件
    $context.ClearBuiltDirectory = {
        & $context.SetStatus $clearBuiltDirectoryStatus
        & $context.DoEvents
        # 删除文件，但是不删除软链接里面的文件（删除软链接本身）
        function Clear-MyDirectory($currentFolder) {
            foreach ($child in (Get-ChildItem $currentFolder)) {
                $isDirectory = ($child.Attributes -band [IO.FileAttributes]::Directory) -ne 0
                $isReparsePoint = ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
                if ($isDirectory) {
                    if ($isReparsePoint) {
                        # 仅删除软链接本身
                        cmd.exe /c rmdir $child.FullName
                        continue
                    }
                    else {
                        Clear-MyDirectory $child.FullName
                    }
                }
                Remove-Item $child.FullName -Force
            }
        }
        $target = New-Item -ItemType Directory -Force -Path $builtDirectory
        Clear-MyDirectory $target.FullName
    }.GetNewClosure()

    # 用于创建天空盒的立方体贴图
    $context.GenerateCubeMap = {
        & $context.SetStatus $generateCubeMapStatus
        $skyboxTexturePath = Get-SkyboxTexturePath $context.NativeWindow
        if ($skyboxTexturePath -eq $Null) {
            & $context.Complete $True
            return
        }

        $cmftProcess = Generate-SkyboxCubeMap $skyboxTexturePath $context.SynchronizationContext
        & $context.ChangeTrackedProcesses $cmftProcess
        $cmftProcess.Add_Exited($context.OnCubeMapGenerationEnd)
        $cmftProcess.Start()
        & $context.ShowCancelText
    }.GetNewClosure()

    $context.OnCubeMapGenerationEnd = {
        param ($sender)

        & $context.ChangeTrackedProcesses $Null
        & $context.HideCancelText
        if (-not $sender.Succeeded) {
            & $context.Complete $False
            return
        }

        $skyboxXmlFile = Get-Item $skyboxXml
        [IO.File]::WriteAllText($skyboxXmlFile.FullName, $skyboxXmlContent)
        & $context.StartWrathEd
    }.GetNewClosure()

    # 用于启动 WED、编译补丁
    $context.StartWrathEd = {
        & $context.SetStatus $wedStatus
        Start-WrathEd $context.SynchronizationContext $context.ChangeTrackedProcesses $context.OnWrathEdCompleted
    }.GetNewClosure()

    $context.OnWrathEdCompleted = {
        param ($succeeded)

        if (-not $succeeded) {
            & $context.Complete $False
            return
        }

        if ($willCopyAdditionalFiles) {
            & $context.SetStatus $copyAdditionalFilesStatus
            & $context.DoEvents

            $additionalFiles = Join-Path $additionalFilesDirectory "*"
            Copy-Item -Path $additionalFiles -Destination $builtDirectory -Force -Recurse
            if (-not $?) {
                & $context.Complete $False
                return        
            }
        }

        if ($willCreateBigFile) {
            & $context.SetStatus $createBigFileStatus
            & $context.DoEvents

            Create-BigFile $builtDirectory $context.NativeWindow
        }
        & $context.Complete $True
    }.GetNewClosure()

    if ($willClearBuiltDirectory) {
        & $context.ClearBuiltDirectory
    }

    if ($willGenerateCubeMap) {
        & $context.GenerateCubeMap
    }
    else {
        & $context.StartWrathEd
    }
}

function global:Get-SkyboxTexturePath($nativeWindow) {
    $openFileDialog = New-Object Windows.Forms.OpenFileDialog
    try {
        $openFileDialog.Title = $chooseSkyboxTextureTitle
        $openFileDialog.Filter = $skyboxTextureFilter
        if ($openFileDialog.ShowDialog($nativeWindow) -eq [Windows.Forms.DialogResult]::OK) {
            return $openFileDialog.FileName
        }
    }
    finally {
        $openFileDialog.Dispose()
    }
    return $Null
}

function global:Generate-SkyboxCubeMap($texturePath, $synchronizationContext) {
    $args = @(
        "--input `"$texturePath`""
        "--filter radiance"
        "--edgefixup warp"
        "--srcFaceSize 0"
        "--excludeBase true"
        "--mipCount 9"
        "--generateMipChain false"
        "--glossScale 17"
        "--glossBias 3"
        "--lightingModel blinnbrdf"
        "--dstFaceSize 0"
        "--numCpuProcessingThreads 4"
        "--useOpenCL true"
        "--clVendor anyGpuVendor"
        "--deviceType gpu"
        "--inputGammaNumerator 1.0"
        "--inputGammaDenominator 1.0"
        "--outputGammaNumerator 1.0"
        "--outputGammaDenominator 1.0"
        "--output0 `"$outputCubeMap`""
        "--output0params dds,bgra8,cubemap"
    ) -join " "
    return [JobSupport]::Prepare($cmftPath, $args, $synchronizationContext)
}

function global:Start-WrathEd($synchronizationContext, $changeTrackedProcesses, $onCompleted) {
    
    $builtDataDirectory = [IO.Path]::Combine($builtDirectory, "data")
    New-Item -ItemType Directory -Force -Path $builtDataDirectory | Out-Null

    function Get-LodName($originalPath, $lodPostFix) {
        $directory = [IO.Path]::GetDirectoryName($originalPath)
        $stem = [IO.Path]::GetFileNameWithoutExtension($originalPath)
        $stems = $stem -split "(?=[^\w])"
        $stems[$stems.Length - 2] += $lodPostFix
        $stem = -join $stems
        $newFileName = $stem + [IO.Path]::GetExtension($originalPath)
        return Join-Path $directory $newFileName
    }
    $inputXmlM = Get-LodName $inputXml "_m"
    $inputXmlL = Get-LodName $inputXml "_l"
    $basePatchStream = Join-Path $basePatchStreamDirectory $basePatchStreamName
    $basePatchStreamM = Get-LodName $basePatchStream "_m"
    $basePatchStreamL = Get-LodName $basePatchStream "_l"

    function Get-WedArguments($xml, $bps) {
        $bpsName = (Get-Item $bps).Name
        return @(
            "-gameDefinition:`"Red Alert 3`""
            "-compile:`"$xml`""
            "-out `"$builtDataDirectory`""
            "-version:`"$newStreamVersion`""
            "-bps:`"$bpsName,$bps`""
        ) -join " "
    }

    $context = @{
        Args = (Get-WedArguments $inputXml $basePatchStream)
        ArgsM = (Get-WedArguments $inputXmlM $basePatchStreamM)
        ArgsL = (Get-WedArguments $inputXmlL $basePatchStreamL)
        ChangeTrackedProcesses = $changeTrackedProcesses
        OnCompleted = $onCompleted 
        SynchronizationContext = $synchronizationContext
        
        Steps = @()
        StepCounter = 0
    }

    $context.LaunchWrathEd = {
        param ($context, $args)
        [Console]::WriteLine("WED Arguments: $($args)");
        $process = [JobSupport]::Prepare($wrathEdPath, $context.Args, $context.SynchronizationContext)
        & $context.ChangeTrackedProcesses $process
        $process.Add_Exited($context.StepEnd)
        $process.WorkingDirectory = $builtDirectory
        $process.Start()
    }

    if ($willCompilePatch) {
        $context.Steps += {
            param ($context)
            & $context.LaunchWrathEd $context $context.Args
        }
    }

    if ($willCompilePatchLodLevels) {
        $context.Steps += {
            param ($context)
            & $context.LaunchWrathEd $context $context.ArgsM
        }
        $context.Steps += {
            param ($context)
            & $context.LaunchWrathEd $context $context.ArgsL
        }
    }

    $context.StepEnd = {
        param ($sender)
        $succeeded = $sender.Succeeded
        & $context.ChangeTrackedProcesses $Null
        # WED 会自动生成 stringhashes 的 stream，这是不需要的，因此删了它
        $stringHashes = Join-Path $builtDataDirectory "stringhashes.*"
        Remove-Item $stringHashes
        if (-not $succeeded) {
            & $context.OnCompleted $False
            return
        }
        $context.StepCounter = $context.StepCounter + 1
        if ($context.StepCounter -lt $context.Steps.Length) {
            & $context.Steps[$context.StepCounter] $context
        }
        else {
            & $context.OnCompleted $True
            return
        }
    }.GetNewClosure()

    if ($context.Steps.Length -gt 0) {
        & $context.Steps[0] $context
    }
    else {
        & $context.OnCompleted $True
    }
}

function global:Create-BigFile($sourceDirectory, $nativeWindow) {
    $list = New-Object Collections.Generic.List[HashTable]
    Get-BigFileList $list "" (Get-Item "$sourceDirectory")
    if ($list.Count -eq 0) {
        [Windows.Forms.MessageBox]::Show([string]::Format($emptyBigMessage, $Error[0]), $mainTitle)
        return
    }

    $outputFile = New-Item $outputBigPath -ItemType File -Force
    $output = [IO.File]::Open($outputFile.FullName, [IO.FileMode]::Create)
    try {
        function Write-ByteArray($array) {
            $output.Write($array, 0, $array.Length)
        }

        function Write-BigEndianValue($v) {
            $array = [BitConverter]::GetBytes($v)
            if ([BitConverter]::IsLittleEndian) {
                [Array]::Reverse($array)
            }
            Write-ByteArray $array
        }

        function Check-StreamPosition() {
            if ($output.Position -gt [UInt32]::MaxValue) {
                throw [IO.IOException]"BIG File too large"
            }
        }

        # BIG 头
        Write-ByteArray ([Text.Encoding]::ASCII.GetBytes("BIG4"))
        # 先跳过文件大小
        $output.Position += 4
        # 文件数量
        Write-BigEndianValue ([UInt32]($list.Count))
        # 先跳过“第一个文件的位置”
        $output.Position += 4

        # 文件列表
        foreach ($entry in $list) {
            & Check-StreamPosition
            $entry.EntryOffset = $output.Position
            # 先跳过大小以及位置
            $output.Position += 8
            # 先写下文件名
            Write-ByteArray $entry.PathBytes
            # 0 结尾的字符串
            $output.WriteByte([byte]0)
        }

        $firstEntryOffset = $output.Position
        # 写入文件内容
        $buffer = New-Object byte[] 81920
        foreach ($entry in $list) {
            $fromFile = $entry.File.OpenRead()
            try {
                $entry.FileOffset = $output.Position
                $bytesRead = 0
                do {
                    & Check-StreamPosition
                    $bytesRead = $fromFile.Read($buffer, 0, $buffer.Length)
                    $output.Write($buffer, 0, $bytesRead)
                }
                while ($bytesRead -gt 0)
                $entry.FileSize = ($output.Position - $entry.FileOffset)
            }
            finally {
                $fromFile.Dispose()
            }
        }

        $bigFileSize = $output.Position

        # 回到开头
        $output.Position = 4
        Write-BigEndianValue ([UInt32]($bigFileSize))
        $output.Position += 4
        Write-BigEndianValue ([UInt32]($firstEntryOffset))

        # 继续写完文件列表
        foreach ($entry in $list) {
            $output.Position = $entry.EntryOffset
            # 写入大小以及位置
            Write-BigEndianValue ([UInt32]($entry.FileOffset))
            Write-BigEndianValue ([UInt32]($entry.FileSize))
        }
    }
    catch {
        [Windows.Forms.MessageBox]::Show([string]::Format($saveFailedMessage, $_), $mainTitle)
        explorer.exe "/select,`"$($outputFile.FullName)`""
        return
    }
    finally {
        $output.Dispose()
    }

    # 弹出“保存”的对话框，选择一个地方保存
    $finalBigName = $Null
    $saveFileDialog = New-Object Windows.Forms.SaveFileDialog
    try {
        $saveFileDialog.Title = $saveBigFileTitle
        $saveFileDialog.Filter = $bigFileFilter
        if ($saveFileDialog.ShowDialog($nativeWindow) -eq [Windows.Forms.DialogResult]::OK) {
            $finalBigName = $saveFileDialog.FileName
        }
    }
    finally {
        $saveFileDialog.Dispose()
    }

    if ($finalBigName -ne $Null) {
        Move-Item -Path $outputBigPath -Destination $finalBigName -Force
        if (-not $?) {
            [Windows.Forms.MessageBox]::Show([string]::Format($saveFailedMessage, $Error[0]), $mainTitle)
        }
    }
}

function Get-BigFileList($outList, $currentPrefix, $currentDirectory) {
    # 文件夹
    foreach ($child in $currentDirectory.GetDirectories()) {
        $name = $child.Name.ToLowerInvariant()
        $childPath = "$currentPrefix$name"
        Get-BigFileList $outList "$childPath\" $child
    }
    # 文件
    foreach ($child in $currentDirectory.GetFiles()) {
        $name = $child.Name.ToLowerInvariant()
        $childPath = "$currentPrefix$name"

        $outList.Add(@{
            File = $child
            PathBytes = [Text.Encoding]::UTF8.GetBytes($childPath)
        })
    }
}

Set-Location $PSScriptRoot
[Environment]::CurrentDirectory = $PSScriptRoot

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$jobSupport = @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

public class JobSupport
{
    public enum JOBOBJECTINFOCLASS
    {
        AssociateCompletionPortInformation = 7,
        BasicLimitInformation = 2,
        BasicUIRestrictions = 4,
        EndOfJobTimeInformation = 6,
        ExtendedLimitInformation = 9,
        SecurityLimitInformation = 5,
        GroupInformation = 11
    }

    [StructLayout(LayoutKind.Sequential)]
    struct JOBOBJECT_BASIC_LIMIT_INFORMATION
    {
        public Int64 PerProcessUserTimeLimit;
        public Int64 PerJobUserTimeLimit;
        public UInt32 LimitFlags;
        public UIntPtr MinimumWorkingSetSize;
        public UIntPtr MaximumWorkingSetSize;
        public UInt32 ActiveProcessLimit;
        public Int64 Affinity;
        public UInt32 PriorityClass;
        public UInt32 SchedulingClass;
    }


    [StructLayout(LayoutKind.Sequential)]
    struct IO_COUNTERS
    {
        public UInt64 ReadOperationCount;
        public UInt64 WriteOperationCount;
        public UInt64 OtherOperationCount;
        public UInt64 ReadTransferCount;
        public UInt64 WriteTransferCount;
        public UInt64 OtherTransferCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION
    {
        public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
        public IO_COUNTERS IoInfo;
        public UIntPtr ProcessMemoryLimit;
        public UIntPtr JobMemoryLimit;
        public UIntPtr PeakProcessMemoryUsed;
        public UIntPtr PeakJobMemoryUsed;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr CreateJobObject(IntPtr lpJobAttributes, string lpName);

    [DllImport("kernel32.dll")]
    public static extern bool AssignProcessToJobObject(IntPtr hJob, IntPtr hProcess);

    [DllImport("kernel32.dll")]
    public static extern bool SetInformationJobObject(IntPtr hJob, JOBOBJECTINFOCLASS JobObjectInfoClass, IntPtr lpJobObjectInfo, uint cbJobObjectInfoLength);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetCurrentProcess();

    public class TrackedProcess
    {
        private Process _process;
        private SynchronizationContext _synchronizationContext;
        private bool _succeeded;

        public bool Succeeded { get { return _succeeded; } }
        public string WorkingDirectory
        {
            get { return _process.StartInfo.WorkingDirectory; }
            set { _process.StartInfo.WorkingDirectory = value; }
        }
        public event EventHandler Exited;

        public TrackedProcess(Process process, SynchronizationContext synchronizationContext)
        {
            _process = process;
            _synchronizationContext = synchronizationContext;
            _process.EnableRaisingEvents = true;
            _process.Exited += ExitEventHandler;
        }

        public void Start()
        {
            _process.Start();
        }

        public void Kill()
        {
            _process.Kill();
        }

        private void ExitEventHandler(object sender, EventArgs e)
        {
            _succeeded = _process.ExitCode == 0;
            _process.Exited -= ExitEventHandler;
            _synchronizationContext.Post(ActualEventExecutor, null);
            _process.Dispose();
        }

        private void ActualEventExecutor(object state)
        {
            EventHandler handlers = Exited;
            Exited = null;
            if (handlers != null)
            {
                handlers(this, EventArgs.Empty);
            }
        }
    }

    private const UInt32 JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x2000;
    private static bool _initialized = false;

    public static TrackedProcess Prepare(string fileName, string arguments, SynchronizationContext context)
    {
        if (!_initialized)
        {
            Initialize();
        }

        Process process = new Process();
        process.StartInfo.FileName = fileName;
        process.StartInfo.Arguments = arguments;
        process.StartInfo.UseShellExecute = false;

        return new TrackedProcess(process, context);
    }

    private static bool Initialize()
    {
        IntPtr job = CreateJobObject(IntPtr.Zero, null);

        JOBOBJECT_BASIC_LIMIT_INFORMATION info = new JOBOBJECT_BASIC_LIMIT_INFORMATION();
        info.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;

        JOBOBJECT_EXTENDED_LIMIT_INFORMATION extendedInfo = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
        extendedInfo.BasicLimitInformation = info;

        int length = Marshal.SizeOf(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
        IntPtr extendedInfoPtr = Marshal.AllocHGlobal(length);
        try
        {
            Marshal.StructureToPtr(extendedInfo, extendedInfoPtr, false);

            SetInformationJobObject(job, JOBOBJECTINFOCLASS.ExtendedLimitInformation, extendedInfoPtr, (uint)length);

            IntPtr hProcess = GetCurrentProcess();
            return AssignProcessToJobObject(job, hProcess);
        }
        finally
        {
            Marshal.FreeHGlobal(extendedInfoPtr);
        }
    }
}
"@
Add-Type -TypeDefinition $jobSupport
$nativeWindow = New-Object Windows.Forms.NativeWindow
Initialize-Wpf $window $nativeWindow
$window.ShowDialog()
$nativeWindow.ReleaseHandle()