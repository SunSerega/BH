library Timer;

{$reference '..\..\BHModuleData.dll'}
uses BHModuleData;

type
  TimerModule=class(BHModule)
  
    protected function ApplySettings(Settings: Dictionary<string, string>; used_lst: List<string>): boolean; override;
    begin
      Result := inherited ApplySettings(Settings, used_lst);
      
      inherited FinishSettings(Settings, used_lst);
    end;
    
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