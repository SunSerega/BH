library Timer;

{$reference '..\..\BHModuleData.dll'}
uses BHModuleData;

type
  TimerModule=class(BHModule)
    
    protected procedure StartUp; override;
    begin
      writeln('Timer Started');
    end;
    
    protected procedure ShutDown; override;
    begin
      writeln('Timer Stoped');
    end;
    
    public property Name: string read 'Timer'; override;
    
    
  end;

end.