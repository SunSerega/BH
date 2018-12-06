library BHModuleData;

{$reference System.Windows.Forms.dll}
{$reference System.Drawing.dll}
uses System.Windows.Forms;
uses System.Drawing;

uses System.Reflection;

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
    
    ///Collection of all modules
    public static property Modules: System.Collections.Generic.IReadOnlyCollection<BHModule> read All.Values;
    
    private static function LoadSettings(var Settings: Dictionary<string, Dictionary<string, string>>): boolean;
    begin
      
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
      
      Settings := new Dictionary<string, Dictionary<string, string>>;
      
      foreach var l in ReadLines('settings.dat') do
      begin
        if l='' then continue;
        
        var ss := l.Split(new char[]('='), 2);
        if ss.Length<>2 then
        begin
          Result := true;
          ss := new string[](ss[0], '');
        end;
        
        var key := ss[0].Trim(' ', #9).Split(new char[](':'), 2);
        if key.Length<>2 then
        begin
          Result := true;
          key := new string[](key[0], '');
        end;
        
        var MName := key[0].Trim(' ', #9);
        var SName := key[1].Trim(' ', #9);
        var SVal := ss[1].Trim(' ', #9);
        
        if not Settings.ContainsKey(MName) then Settings[MName] := new Dictionary<string, string>;
        var MSettings := Settings[MName];
        
        if MSettings.ContainsKey(SName) then
          if MSettings[SName] = SVal then
            Result := true else
            case MessageBox.Show(
              
              $'Key "{MName}:{SName}" was found multiple times in "settings.dat" file.{#10}' +
              $'First value is "{MSettings[SName]}".{#10}' +
              $'New value is "{SVal}".{#10}' +
              $'Rewrite first value with new one?',
              
              $'Conflicting settings keys',
              
              MessageBoxButtons.YesNo
            ) of
              DialogResult.Yes: Result := true;
              else continue;//foreach var l
            end;
        
        MSettings[SName] := SVal;
        
      end;
      
    end;
    
    private static procedure SaveSettings(Settings: Dictionary<string, Dictionary<string, string>>);
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
    
    private static NewSettings := new Dictionary<string, Dictionary<string, string>>;
    
    public static constructor :=
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
        if t.IsAbstract then continue;
        var constr := t.GetConstructor(System.Type.EmptyTypes);
        if constr=nil then continue;
        var nm := BHModule(constr.Invoke(new object[0]));
        
        if All.ContainsKey(nm.Name) then
        begin
          MessageBox.Show(
            
            $'Every module must have unique name{#10}' +
            $'But more than one "{nm.Name}" modules was found{#10}' +
            $'Press OK to exit BH',
            
            $'Conflicting module name''s'
            
          );
          Halt;
        end;
        
        All.Add(nm.Name, nm);
      end;
      
      {$endregion Load Modules}
      
      var Settings: Dictionary<string, Dictionary<string, string>>;
      var ReSaveSettings := LoadSettings(Settings);
      
      {$region Use settings on modules}
      
      foreach var m in Modules do
      begin
        if not Settings.ContainsKey(m.Name) then
        begin
          ReSaveSettings := true;
          Settings[m.Name] := new Dictionary<string, string>;
        end;
        
        ReSaveSettings := m.ApplySettings(Settings[m.Name]) or ReSaveSettings;
        
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
            else continue;
          end;
      
      {$endregion Use settings on modules}
      
      if ReSaveSettings then
        SaveSettings(Settings);
      
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
    
    protected procedure OverrideSetting(SName, SVal: string);
    begin
      var MName := self.Name;
      if not NewSettings.ContainsKey(MName) then NewSettings[MName] := new Dictionary<string, string>;
      NewSettings[MName][SName] := SVal;
    end;
    
    private static procedure SaveNewSettings;
    begin
      
      var Settings: Dictionary<string, Dictionary<string, string>>;
      var ReSaveSettings := LoadSettings(Settings);
      
      foreach var kvp1 in NewSettings do
      begin
        if not Settings.ContainsKey(kvp1.Key) then Settings[kvp1.Key] := new Dictionary<string, string>;
        
        foreach var kvp2 in kvp1.Value do
          if
            (not Settings[kvp1.Key].ContainsKey(kvp2.Key)) or
            (Settings[kvp1.Key][kvp2.Key] <> kvp2.Value)
          then
          begin
            ReSaveSettings := true;
            Settings[kvp1.Key][kvp2.Key] := kvp2.Value;
          end;
        
      end;
      NewSettings.Clear;
      
      if ReSaveSettings then
        SaveSettings(Settings);
      
    end;
    
    public static procedure GetReadyForExit;
    begin
      
      foreach var m in Modules do
        if m.Runing then
          m.ShutDown;
      
      SaveNewSettings;
      
    end;
    
    {$endregion static}
    
    {$region MainBody}
    
    private is_on := false;
    ///Is module active
    ///This property call's StartUp/ShutDown when value is changed
    public property Runing: boolean read is_on write
    begin
      if is_on=value then exit;
      
      if value then
        StartUp else
        ShutDown;
      
      is_on := value;
      OverrideSetting('Active', value.ToString);
      
    end;
    
    
    
    ///Standard settings load start
    ///It load's value of "Runing" from setting "Active",
    ///and add's "Active" to used settings list
    ///Return's true if "Active" setting was corrupted (or missing) and therefore recreated
    ///Default value of "Active" is "True"
    protected function ApplySettings_Start(Settings: Dictionary<string, string>; used_lst: List<string>): boolean;
    begin
      Result := false;
      
      var Run_bool := true;
      var Run_str := Run_bool.ToString;
      
      if
        (not Settings.TryGetValue('Active', Run_str)) or
        (not boolean.TryParse(Run_str, Run_bool))
      then
      begin
        Result := true;
        Run_bool := true;
        Settings['Active'] := Run_bool.ToString;
      end;
      
      used_lst += 'Active';
      self.Runing := Run_bool;
      
    end;
    ///Executed when loading
    ///Must return true if it changed contents of "Settings" variable
    protected function ApplySettings(Settings: Dictionary<string, string>): boolean; virtual;
    begin
      var used_lst := new List<string>;
      Result := ApplySettings_Start(Settings, used_lst);
      Result := ApplySettings_End(Settings, used_lst) or Result;
    end;
    ///Standard settings load end
    ///Deletes all unused settings
    ///Return's true if any settings was deleted
    protected function ApplySettings_End(Settings: Dictionary<string, string>; used_lst: List<string>): boolean;
    begin
      Result := false;
      
      foreach var kvp in Settings.ToList do
        if not used_lst.Contains(kvp.Key) then
        begin
          Result := true;
          Settings.Remove(kvp.Key);
        end;
      
    end;
    
    ///Executed every time module restart's
    ///Including first start (if setting "Active" was "true")
    protected procedure StartUp; abstract;
    ///Executed every time module is shut's down
    ///Including time when BH shut's down
    protected procedure ShutDown; abstract;
    
    
    
    ///Must return unique name
    public property Name: string read; abstract;
    
    {$resource 'Icons\default module icon.bmp'}
    ///Must return System.Drawing.Image that represents module
    public property Icon: Bitmap read new Bitmap(Assembly.GetExecutingAssembly.GetManifestResourceStream('default module icon.bmp')); virtual;
    
    {$endregion MainBody}
    
    {$region Misc}
    
    ///Return's $"BHModule[\"{Name}\"]"
    ///This is only for debug, so you can override it, if you want
    public function ToString: string; override :=
    $'BHModule["{Name}"]';
    
    {$endregion Misc}
    
  end;
  
end.