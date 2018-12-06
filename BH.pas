{$apptype windows}

{$reference BHModuleData.dll}

uses BHFormData;
uses ModuleManagerData;

uses System.Windows.Forms;

procedure ApplyCommandLineArgs;
begin
  
end;

procedure CheckPrev;
begin
  
  var CurrBH := System.Diagnostics.Process.GetCurrentProcess;
  
  var PrevBH :=
    System.Diagnostics.Process.GetProcessesByName('BH')
    .where(proc->proc.StartTime <= CurrBH.StartTime)
    .MinBy(proc->proc.StartTime.Ticks);
  if PrevBH.Id=CurrBH.Id then exit;
  
  var pipe := new System.IO.Pipes.NamedPipeClientStream('BH restart');
  while true do
  begin
    try
      pipe.Connect(3000);
      break;
    except
    end;
    
    if PrevBH.HasExited then
    begin
      
      var NewBH :=
        System.Diagnostics.Process.GetProcessesByName('BH')
        .MinBy(proc->proc.StartTime.Ticks);
      
      if NewBH.Id = CurrBH.Id then
        exit else
        Halt;
      
    end;
    
  end;
  
  var bw := new System.IO.BinaryWriter(pipe);
  var br := new System.IO.BinaryReader(pipe);
  
  bw.Write(CommandLineArgs.Length);
  foreach var arg in CommandLineArgs do bw.Write(arg);
  pipe.WaitForPipeDrain;
  
  if br.ReadBoolean then Halt;
  
end;

procedure StartPipeServer :=
try
  var pipe := new System.IO.Pipes.NamedPipeServerStream('BH restart', System.IO.Pipes.PipeDirection.InOut, 2);
  
  while true do
  begin
    pipe.WaitForConnection;
    
    var bw := new System.IO.BinaryWriter(pipe);
    var br := new System.IO.BinaryReader(pipe);
    
    CommandLineArgs := new string[br.ReadInt32];
    CommandLineArgs.Fill(i->br.ReadString);
    
    if CommandLineArgs.Length=0 then
    begin
      
      if BHForm.f=nil then
      begin
        
        bw.Write(false);
        foreach var m in BHModule.Modules do m.Runing := false;
        pipe.WaitForPipeDrain;
        Halt;
        
      end else
      begin
        
        bw.Write(true);
        var f := BHForm.f;
        BHForm.f := nil;
        f.Close;
        pipe.WaitForPipeDrain;
        
      end;
      
    end else
    begin
      
      bw.Write(true);
      ApplyCommandLineArgs;
      pipe.WaitForPipeDrain;
      
    end;
    
    pipe.Disconnect;
  end;
  
except
  on e: Exception do
  begin
    MessageBox.Show(
      _ObjectToString(e),
      'critical error in server thread'
    );
    Halt;
  end;
end;

procedure StartForm :=
try
  Application.Run(BHForm.f);
except
  on e: Exception do
  begin
    MessageBox.Show(
      _ObjectToString(e),
      'critical error in form thread'
    );
    Halt;
  end;
end;

begin
  try
    
    CheckPrev;
    ApplyCommandLineArgs;
    System.Threading.Thread.Create(StartPipeServer).Start;
    System.Threading.Thread.Create(StartForm).Start;
    ModuleManager.StartManaging;
    
  except
    on e: Exception do
    begin
      MessageBox.Show(
        _ObjectToString(e),
        'critical error in main thread'
      );
      Halt;
    end;
  end;
end.