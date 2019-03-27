library BHModuleData;

interface

{$reference System.Windows.Forms.dll}
{$reference System.Drawing.dll}
uses System.Windows.Forms;
uses System.Drawing;

uses System.Reflection;

uses MiscData;
uses GData, MenuData;

type
  BHModule = abstract class
    
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
    
    private source_file: string;
    
    
    
    ///Standard settings load start
    ///It load's value of property "Runing" from setting "Active",
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
    public property Icon: Bitmap read new Bitmap(Assembly.GetCallingAssembly.GetManifestResourceStream('default module icon.bmp')); virtual;
    
    {$endregion MainBody}
    
    {$region static}
    
    private static All := new Dictionary<string, BHModule>;
    
    ///Find's module by it's name
    ///This is a default static index property
    public static property Module[id: string]: BHModule read All[id]; default;
    
    ///Collection of all modules
    public static property Modules: System.Collections.Generic.IReadOnlyCollection<BHModule> read All.Values;
    
    static constructor;
    
    private static function LoadSettings(var Settings: Dictionary<string, Dictionary<string, string>>): boolean;
    begin
      
      var fi := new System.IO.FileInfo('settings (backup).dat');
      if fi.Exists and (fi.Length<>0) then
      begin
        System.IO.File.Copy('settings (backup).dat', 'settings.dat', true);
        System.IO.File.Delete('settings (backup).dat');
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
        
        var key := ss[0].Split(new char[](':'), 2);
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
              $'Rewrite first value with new one?{#10}' +
              $'(Press "cancel" to exit BH without saving)',
              
              $'Conflicting settings keys',
              
              MessageBoxButtons.YesNoCancel
            ) of
              DialogResult.Yes: Result := true;
              DialogResult.Cancel: Halt;
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
          sw.WriteLine($'{kvp1.Key}:{kvp2.Key}={kvp2.Value}');
      
      sw.Close;
      System.IO.File.Delete('settings (backup).dat');
      
    end;
    
    private static NewSettings := new Dictionary<string, Dictionary<string, string>>;
    
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
    
    {$region Misc}
    
    ///Return's $"BHModule[\"{Name}\"]"
    ///This is only for debug, so you can override it, if you want
    public function ToString: string; override :=
    $'BHModule["{Name}"]';
    
    {$endregion Misc}
    
  end;
  
  Image = GData.Image;
  Painter = GData.Painter;
  
  MenuBase = MenuData.MenuBase;
  Menu<T> = MenuData.Menu<T>;
  
  CircleMenuData = MenuData.CircleMenuData;
  CircleMenu = MenuData.CircleMenu;
  
implementation

procedure TryLoadAssembly;
begin
  var fname := string(System.AppDomain.CurrentDomain.GetData('fname'));
  
  System.AppDomain.CurrentDomain.SetData(
    'tps',
    Assembly.LoadFile(fname)
    .GetExportedTypes
    .Where(t -> not t.IsAbstract)
    .Where(t -> t.IsSubclassOf(typeof(BHModule)))
    .Where(t -> t.GetConstructor(System.Type.EmptyTypes) <> nil)
    .Select(t->t.FullName)
    .ToHashSet
  );
  
end;

static constructor BHModule.Create :=
try
  
  {$region Load Modules}
  
  foreach var nm: BHModule in
    System.IO.Directory.EnumerateDirectories(System.IO.Path.GetFullPath('Modules'))
    .SelectMany(
      fld->
      System.IO.Directory.EnumerateFiles(fld, '*.dll')
      .SelectMany(
        fname->
        begin
          var ad := System.AppDomain.CreateDomain($'Domain for BH modules from file {fname}');
          
          ad.SetData('fname', fname);
          ad.DoCallBack(TryLoadAssembly);
          var tps := HashSet&<string>(ad.GetData('tps'));
          System.AppDomain.Unload(ad);
          
          Result :=
            Assembly.LoadFile(fname)
            .GetExportedTypes
            .Where(t -> tps.Contains(t.FullName))
            .Select(
              t ->
              begin
                Result :=
                  BHModule(
                    t.GetConstructor(
                      System.Type.EmptyTypes
                    ).Invoke(new object[0])
                  );
                Result.source_file := fname;
              end
            );
          
        end
      )
    )
  do
  begin
    
    if All.ContainsKey(nm.Name) then
    begin
      MessageBox.Show(
        
        $'Theese 2 modules have name "{nm.Name}"{#10}' +
        #10 +
        $'Class {All[nm.Name].GetType.FullName}{#10}' +
        $'From file "{All[nm.Name].source_file}"{#10}' +
        #10 +
        $'Class {nm.GetType.FullName}{#10}' +
        $'From file "{nm.source_file}"{#10}' +
        #10 +
        $'Press OK to exit BH',
        
        $'Conflicting module names'
        
      );
      Halt;
    end;
    
    All.Add(nm.Name, nm);
  end;
  
  if All.Count=0 then
  begin
    MessageBox.Show(
      
      'No modules were found'#10
      'There is no reason to start BH without modules'
      
    );
    Halt;
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
    
  end;
  
  var names := Modules.Select(m->m.Name).ToHashSet;
  
  foreach var kvp in Settings.ToList do
    if not names.Contains(kvp.Key) then
      case MessageBox.Show(
        
        $'Module "{kvp.Key}" was not found.{#10}' +
        $'Delete it''s settings?',
        
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
  on e: Exception do ShowCriticalError(e, 'critical error initializing modules');
end;

end.