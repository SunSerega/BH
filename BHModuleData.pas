library BHModuleData;

{$reference System.Windows.Forms.dll}

uses System.Reflection;

type
  BHModule = abstract class
    
    {$region static}
    
    public static All := new List<BHModule>;
    
    private static function GetAllBaseTypes(t: System.Type): sequence of System.Type;
    begin
      var base := t.BaseType;
      if base=nil then exit;
      yield base;
      yield sequence GetAllBaseTypes(base);
    end;
    
    static constructor :=
    try
      
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
        var nm := BHModule(t.GetConstructor(System.Type.EmptyTypes).Invoke(new object[0]));
        All.Add(nm);
        nm.Runing := true;//ToDo
      end;
      
    except
      on e: Exception do
      begin
        try
          System.Windows.Forms.MessageBox.Show(
            _ObjectToString(e),
            'critical error initializing modules'
          );
        except
          System.Windows.Forms.MessageBox.Show(
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