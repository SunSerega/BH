library BHModuleData;

{$reference System.Windows.Forms.dll}

uses System.Reflection;
uses System.Windows.Forms;

type
  BHModule = abstract class
    
    {$region static}
    
    private static All := new Dictionary<string, BHModule>;
    
    private static function GetAllBaseTypes(t: System.Type): sequence of System.Type;
    begin
      var base := t.BaseType;
      if base=nil then exit;
      yield base;
      yield sequence GetAllBaseTypes(base);
    end;
    
    //ToDo в следующем билде можно убрать
    private static function _GetModuleById(id: string): BHModule := All[id];
    
    private static property Item[id: string]: BHModule read _GetModuleById; default;
    
    public static property Modules: System.Collections.Generic.IReadOnlyCollection<BHModule> read All.Values;
    
    static constructor :=
    try
      
      {$region Load Modules}
      
      foreach var t: System.Type in
        System.IO.Directory.EnumerateDirectories(System.IO.Path.GetFullPath('Modules'))
        .SelectMany(
          fld->
          System.IO.Directory.EnumerateFiles(fld)
          .Where(fname->fname.EndsWith('.dll'))
          .SelectMany(fname->
          {}Assembly.LoadFile(fname)
          {}.GetExportedTypes
          {}.Where(
          {}  t->
          {}  t.IsSubclassOf(typeof(BHModule))
          {})
          )
        )
      do
      begin
        var constr := t.GetConstructor(System.Type.EmptyTypes);
        if constr=nil then continue;
        var nm := BHModule(constr.Invoke(new object[0]));
        All.Add(nm.Name, nm);
      end;
      
      {$endregion Load Modules}
      
      {$region Load settings}
      
      if System.IO.File.Exists('settings (backup).dat') then
        case MessageBox.Show(
          $'Probably, last time settings were saving, issue occurred.{#10}' +
          $'Load backup?',
          $'Settings backup found',
          MessageBoxButtons.YesNo
        ) of
          DialogResult.Yes:
          begin
            System.IO.File.Copy('settings (backup).dat', 'settings.dat', true);
            System.IO.File.Delete('settings (backup).dat');
          end;
        end;
      
      var Settings := new Dictionary<string, Dictionary<string, string>>;
      var ReSaveSettings := false;
      
      foreach var l in ReadLines('settings.dat') do
      begin
        if l='' then continue;
        
        var ss := l.Split(new char[]('='), 2);
        if ss.Length<>2 then
        begin
          ReSaveSettings := true;
          ss := new string[](ss[0], '');
        end;
        
        var key := ss[0].Trim(' ', #9).Split(new char[](':'), 2);
        if key.Length<>2 then
        begin
          ReSaveSettings := true;
          key := new string[](key[0], '');
        end;
        
        var MName := key[0].Trim(' ', #9);
        var SName := key[1].Trim(' ', #9);
        var SVal := ss[1].Trim(' ', #9);
        
        if not Settings.ContainsKey(MName) then Settings[MName] := new Dictionary<string, string>;
        var MSettings := Settings[MName];
        
        if MSettings.ContainsKey(SName) then
          if MSettings[SName] = SVal then
            ReSaveSettings := true else
            case MessageBox.Show(
              $'Key "{MName}:{SName}" was found multiple times in "settings.dat" file.{#10}' +
              $'First value is "{MSettings[SName]}".{#10}' +
              $'New value is "{SVal}".{#10}' +
              $'Rewrite first value with new one?',
              $'Conflicting settings keys',
              MessageBoxButtons.YesNo
            ) of
              DialogResult.Yes: ReSaveSettings := true;
              else continue;//foreach var l
            end;
        
        MSettings[SName] := SVal;
        
      end;
      
      {$endregion Load settings}
      
      {$region Use settings on modules}
      
      foreach var m in Modules do
      begin
        if not Settings.ContainsKey(m.Name) then
        begin
          ReSaveSettings := true;
          Settings[m.Name] := new Dictionary<string, string>;
        end;
        
        ReSaveSettings := m.ApplySettings(Settings[m.Name], new List<string>) or ReSaveSettings;
        
        Settings[m.Name][#0'=used'] := nil;
      end;
      
      foreach var kvp in Settings.ToList do
        if not kvp.Value.ContainsKey(#0'=used') then
          case MessageBox.Show(
            $'Module "{kvp.Key}" was not found.{#10}' +
            $'Delete it''s settings?{#10}',
            $'Unused settings keys',
            MessageBoxButtons.YesNo
          ) of
            DialogResult.Yes:
            begin
              ReSaveSettings := true;
              Settings.Remove(kvp.Key);
            end;
            else continue;//foreach var l
          end;
      
      {$endregion Use settings on modules}
      
      {$region ReSave Settings}
      
      if ReSaveSettings then
      begin
        
        System.IO.File.Copy('settings.dat', 'settings (backup).dat', true);
        var sw := System.IO.File.CreateText('settings.dat');
        
        foreach var kvp1 in Settings do
          foreach var kvp2 in kvp1.Value do
            if not kvp2.Key.StartsWith(#0) then
              sw.WriteLine($'{kvp1.Key}:{kvp2.Key}={kvp2.Value}');
        
        sw.Close;
        System.IO.File.Delete('settings (backup).dat');
        
      end;
      
      {$endregion ReSave Settings}
      
    except
      on e: Exception do
      begin
        try
          MessageBox.Show(
            _ObjectToString(e),
            'critical error initializing modules'
          );
        except
          MessageBox.Show(
            '*error geting error text*',
            'critical error initializing modules'
          );
        end;
        Halt;
      end;
    end;
    
    {$endregion static}
    
    {$region MainBody}
    
    private is_on := false;
    public property Runing: boolean read is_on write
    begin
      if is_on=value then exit;
      if value then
        StartUp else
        ShutDown;
      is_on := value;
    end;
    
    protected function ApplySettings(Settings: Dictionary<string, string>; used_lst: List<string>): boolean; virtual;
    begin
      Result := false;
      
      var Run_bool := true;
      var Run_str := Run_bool.ToString;
      
      used_lst += 'Active';
      if not Settings.TryGetValue('Active', Run_str) then
      begin
        Result := true;
        Settings['Active'] := Run_bool.ToString;
      end else
      if not boolean.TryParse(Run_str, Run_bool) then
      begin
        Result := true;
        Run_bool := true;
        Settings['Active'] := Run_bool.ToString;
      end;
      
      self.Runing := Run_bool;
      
    end;
    
    protected procedure FinishSettings(Settings: Dictionary<string, string>; used_lst: List<string>);
    begin
      
      foreach var kvp in Settings.ToList do
        if not used_lst.Contains(kvp.Key) then
          Settings.Remove(kvp.Key);
      
    end;
    
    protected procedure StartUp; abstract;
    protected procedure ShutDown; abstract;
    
    public property Name: string read; abstract;
    
    {$endregion MainBody}
    
    {$region Misc}
    
    public function ToString: string; override :=
    $'BHModule["{Name}"]';
    
    {$endregion Misc}
    
  end;
  
end.