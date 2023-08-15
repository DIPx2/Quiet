Function main { 

<#
    .SYNOPSIS
    Обмен файлами между локальным ресурсом и FTP-сервером.

    .DESCRIPTION
    - Использование не подстановочных знаков, а регулярных выражений,
      что позволяет выпиливать файлы точно и индивидуально;
    - В настройках понятно что, откуда, куда и как, самодокументировано;
    - Отчет адаптирован для просмотра и анализа инструментами Excel;
    - Настройки отделены от алгоритма, вероятность ошибки аппроксимируется
      к беспрецедентно низким значениям;
    - Отличная адаптивность к условиям в текущем контексте;
    - Централизация задач, при этом все укладывается в сознании;

    .PARAMETER -declaration
    Значение параметра впиши желаемое.

    .INPUTS
    Входные значение выбираются из параметров файла "abibas.xml".

    .OUTPUTS
    Если цикл обхода каталогов произошел и файлов по шаблону
    регулярных выражений не обнаружено, запись в файл-журнал не
    производится.
    Если возникли возникли ситуации, не дающие возможность выполнить
    цикл обхода каталогов, создается журнал с описанием ошибочной
    ситуации.
    Журнал содается для текущих суток. Неактульные файлы-журналы
    надлежит удалять вручную.

    .NOTES
    - Quiet в значении "тихий". Тихий и информативный.
    - По умолчанию, все локальные каталоги назначены как "/",
      т.е. корень диска, в которм запускается скрипт.
    - Если скрипт работает "не так", почти всегда проблема в неверном паттерне.
    - Версия "G".
    - Дата начала эксплуатации 1/8/2023.
    
#>

    Param ( [Parameter(Mandatory=$true)] [string]$declaration )

	Write-Output ( "{0} {1} {2}" -f "`n`n", ">>>>>>>>>>>>>>>>>>>", $declaration )

	Add-Type -Path "$PSScriptRoot\FluentFTP.dll"

	[xml]$xyz = Get-Content -Path "$PSScriptRoot\abibas.xml"

	$MyFTP = New-Object FluentFTP.FtpClient($xyz.Param.FTP_Sever.IP_FTP)
	$MyFTP.Credentials = New-Object System.Net.NetworkCredential($xyz.Param.FTP_Sever.FTPUserName, $xyz.Param.FTP_Sever.FTPUserPassword)
	$MyFTP.ValidateAnyCertificate = 0
	$MyFTP.EncryptionMode = 0
    $MyFTP.Encoding = [System.Text.Encoding]::GetEncoding(1251)
    
    try{ $MyFTP.AutoConnect | Out-Null } catch { 
    $Stringpterr =  New-Object PSObject -Property @{
			    Date=(Get-Date -Format "dd-MM-yyyy HH:mm:ss")
			    Exception=$_.Exception }
    Export-Csv -InputObject $Stringpterr -Path ("$PSScriptRoot\Reports\" + (Get-Date -Format dd-MM-yyyy) + "_FTP_ERROR.csv") -Delimiter ";" -Encoding UTF8 -Append -NoTypeInformation -NoClobber
    return
    }

	function Report{ 

		Param ( [Parameter(Mandatory=$true)] $УНП,
				[Parameter(Mandatory=$true)] $Организация,
				[Parameter(Mandatory=$true)] $Действие,
				[Parameter(Mandatory=$true)] $ПутьСерверный,
				[Parameter(Mandatory=$true)] $ПутьЛокальный,
				[Parameter(Mandatory=$true)] $ИмяФайла,
				[Parameter(Mandatory=$true)] $Размер,
				[Parameter(Mandatory=$false)][switch]$Ahtung
		)

		if ($Ahtung) { $LL = "$PSScriptRoot\Reports\" + (Get-Date -Forma dd-MM-yyyy) + "_LocalDir_ERROR.csv" } else { $LL = "$PSScriptRoot\Reports\" + (Get-Date -Forma dd-MM-yyyy) + ".csv" }

		$xxxReport = [PSCustomObject]@{
		"Дата операции"=(Get-Date -Format "dd-MM-yyyy HH:mm:ss")
		УНП=$УНП
		Организация=$Организация
		Действие=$Действие
		"Путь серверный"=$ПутьСерверный
		"Путь локальный"=$ПутьЛокальный
		"Имя файла"=$ИмяФайла
		"Размер, байт"=$Размер
		}

		Export-Csv -InputObject $xxxReport -Path $LL -Delimiter ";" -Encoding UTF8 -Append -NoTypeInformation -NoClobber
	}

	function X70 { Param ( [Parameter(Mandatory=$true)] $NameOrg, [Parameter(Mandatory=$true)] $Unp, [Parameter(Mandatory=$true)] $Kits )
        
        [int]$N = 0

		foreach ($k in $kits){

            if ( -not ($k.LocalDir).EndsWith('\') ){ $KitLocalPath = ($k.LocalDir + '\') } else { $KitLocalPath = $k.LocalDir }

            if ( (Test-Path -path $KitLocalPath) -eq $false ){
            Report -УНП $Unp -Организация $NameOrg -Действие 'Abibas-parameter <LocalDir> not found' -ПутьСерверный '' -ПутьЛокальный $KitLocalPath -ИмяФайла '' -Размер '' -Ahtung
            $N = 1
            }
             
            if ( -not ($k.DestinationCopy).EndsWith('\') ){ $KitDestinationCopy = ($k.DestinationCopy + '\') } else { $KitDestinationCopy = $k.DestinationCopy }

            if ( ($KitDestinationCopy.Length -eq 0 -and ($k.CopyFile -like 'Yes')) -or (($KitDestinationCopy.Length -ne 0) -and ($k.CopyFile -like 'Yes') -and (Test-Path -path $KitDestinationCopy) -eq $false) ){
            Report -УНП $Unp -Организация $NameOrg -Действие 'Abibas-parameter <DestinationCopy> not found' -ПутьСерверный '' -ПутьЛокальный $KitDestinationCopy -ИмяФайла '' -Размер '' -Ahtung
            $N = 1
            } 

            if ($N -eq 0){

                try{ $MyFTP.SetWorkingDirectory($k.ServerDir) } catch {
				        $StrErr =  New-Object PSObject -Property @{
							        Date=(Get-Date -Format "dd-MM-yyyy HH:mm:ss")
							        Exception=$_.Exception }
							        Export-Csv -InputObject $StrErr -Path ("$PSScriptRoot\Reports\" + (Get-Date -Format dd-MM-yyyy) + "_FTP_ERROR.csv") -Delimiter ";" -Encoding UTF8 -Append -NoTypeInformation -NoClobber
                        return
				}

			    if ($K.Direction -like "ServerToLocal"){
				    $ListFilesFromFTP = $MyFTP.GetListing("") | where {$_.Type -eq "File"}
				    if ( $ListFilesFromFTP.Count -gt 0 ){
					    foreach ( $String in $ListFilesFromFTP ){

						    if ( $String -match $K.Pattern ){
							    $tmpFD = "$PSScriptRoot\Temp\" + $String.Name

							    if ( $MyFTP.DownloadFile($tmpFD, $String.FullName ) -like "Success" ){
								    Copy-Item $tmpFD -Destination $KitLocalPath -Force
								    Report -УНП $Unp -Организация $NameOrg -Действие $k.DisplayName -ПутьСерверный $k.ServerDir -ПутьЛокальный $KitLocalPath -ИмяФайла  $String.Name -Размер  $String.Size
							    }   
							    if ( $k.CopyFile -like 'Yes' -and $k.CopyFileWithRandom -like 'Yes'){
								    $tmpFileRnd = ($String.Name + '_' + (Get-Random).ToString())
								    Rename-Item -Path $tmpFD -NewName $tmpFileRnd -Force
								    Move-Item -Path ($PSScriptRoot + "\Temp\" + $tmpFileRnd) -Destination $KitDestinationCopy -Force
						        }
						        if ( $k.CopyFile -like 'Yes' -and $k.CopyFileWithRandom -notlike 'Yes' ){
						            Move-Item -Path $tmpFD -Destination $KitDestinationCopy -Force
						        }
						        if ($k.DeletingSourceFile -like 'Yes') { 
                                    $MyFTP.DeleteFile($String.FullName)
						        }
                                if ( $k.CopyFile -like 'No' ){
                                    Remove-Item -Path $tmpFD -Force
                                }
						    }
					    }
				    }
			    }
                if ($K.Direction -like "LocalToServer"){
                    foreach ($xF in (Get-ChildItem -File -Path $KitLocalPath)){
                        if ( $xF -match $k.Pattern ){
                            $FileUpload = Join-Path $KitLocalPath $xF
                            $result = $MyFTP.UploadFile( $FileUpload, ($MyFTP.GetWorkingDirectory() + '/' + $xF) )
                            if ( $result -like 'Success' ){
                                Report -УНП $Unp -Организация $NameOrg -Действие $k.DisplayName -ПутьСерверный $k.ServerDir -ПутьЛокальный $KitLocalPath -ИмяФайла $xF -Размер  (Get-ChildItem $FileUpload).Length
                                if( $k.DeletingSourceFile -like 'Yes' ){
                                    Remove-Item -Path $FileUpload -Force
                                }
                            }
                            if ( $result -like 'Failed' ){
                                Report -УНП $Unp -Организация $NameOrg -Действие $k.DisplayName + ' не отправлен' -ПутьСерверный $k.ServerDir -ПутьЛокальный $KitLocalPath -ИмяФайла $xF -Размер  (Get-ChildItem $FileUpload).Length -Ahtung
                            }
                        }
                    }
                }
            }
		}
	}
	foreach ($e in $xyz.Param.Organization) { x70 -Kits $e.Kit -NameOrg $e.Name -Unp $e.УНП }
}


main -declaration 'Хуй войне, земля крестьянам!'