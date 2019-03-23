unit MenuData;

uses GData;

//ToDo проверить issue
// - #1880
// - #1881

type
  
  ///Base type of Menu<MenuDataT>
  MenuBase = abstract class
    
    protected _owner, curr_child: MenuBase;
    protected progress, prog_dir: integer;
    
    
    
    public property Owner: MenuBase read _owner;
    
    public procedure DrawOn(dx,dy: real; pnt: Painter); abstract;
    
    
    
    public static event UnProcessedEsc: procedure;
    
  end;
  
  ///BH Menu type
  Menu<SubMenuDataT> = abstract class(MenuBase)
    
    protected sub_menus := new List<(MenuBase, SubMenuDataT)>;
    
    public procedure AddMenu(m: MenuBase; data: SubMenuDataT) :=
    sub_menus.Add((m, data));
    
    public procedure RemoveMenu(m: MenuBase) :=
    sub_menus.RemoveAll(t->t[0]=m);
    
  end;
  
  DummyMenu = class(Menu<byte>)
    
    public procedure DrawOn(dx,dy: real; pnt: Painter); override := exit;
    
  end;
  
  ///Container for data of CircleMenu sub-menu
  CircleMenuData = record
    
    Miniature: Painter;
    BackColor: System.ValueTuple<real,real,real,real>;
    
    constructor(Miniature: Painter; BackColor: System.ValueTuple<real,real,real,real>);
    begin
      self.Miniature := Miniature;
      self.BackColor := BackColor;
    end;
    
  end;
  
  ///Menu in which all sub-menu's placed in circle
  CircleMenu = class(Menu<CircleMenuData>)
    
    public const R=450;
    public const iR=150;
    public const MinMenus=5;
    
    
    
    public procedure AddMenu(m: MenuBase; Miniature: Image; cb,cg,cr,ca: real) :=
    AddMenu(m, Miniature, System.ValueTuple.Create(cb,cg,cr,ca));
    
    public procedure AddMenu(m: MenuBase; Miniature: Image; cb,cg,cr,ca: byte) :=
    AddMenu(m, Miniature, new System.ValueTuple<real,real,real,real>(cb/255,cg/255,cr/255,ca/255));
    
    public procedure AddMenu(m: MenuBase; Miniature: Image; BackColor: integer);
    begin
      var pc: ^System.ValueTuple<byte,byte,byte,byte> := pointer(@BackColor);
      AddMenu(m, Miniature, pc^);
    end;
    
    public procedure AddMenu(m: MenuBase; Miniature: Image; BackColor: System.ValueTuple<byte,byte,byte,byte>) :=
    AddMenu(m, Miniature, BackColor.Item1,BackColor.Item2,BackColor.Item3, BackColor.Item4);
    
    public procedure AddMenu(m: MenuBase; Miniature: Image; BackColor: System.ValueTuple<real,real,real,real>) :=
    AddMenu(m, new CircleMenuData(new Painter(Miniature), BackColor));
    
    //ToDo #1880, #1881
    private function lambda1(t: (MenuBase, CircleMenuData)) := t[1].BackColor;
    private clrs := sub_menus.ConvertAll(lambda1);
    private d_cl := System.ValueTuple.Create(0.85,0.85,0.85, 1.0);
    private c := 0;
    private svd_dx, svd_dy: real;
    
    public procedure DrawOn(dx,dy: real; pnt: Painter); override;
    begin
      
      c := Max(MinMenus,sub_menus.Count);
      if c and 1 = 0 then c += 1;
      
      svd_dx := dx;
      svd_dy := dy;
      
      clrs := sub_menus.ConvertAll(t->t[1].BackColor);
      d_cl := System.ValueTuple.Create(0.85,0.85,0.85, 1.0);
      
      pnt.FillRoughDonut(
        dx,dy,
        R,R, iR,iR,
        (x,y)->
        begin
          var ang := System.Math.Atan2(y-svd_dy,x-svd_dx);
          //writeln((x-svd_dx,y-svd_dy,ang));
          var i := Round((ang/Pi + 0.5)*c/2);
          if i<0 then i += c;
          if i<clrs.Count then
            Result := clrs[i] else
            Result := d_cl;
        end
      );
      
      pnt.DrawCircle(dx,dy, iR,iR, 0,0,0,0.5);
      pnt.DrawCircle(dx,dy, R,R,   0,0,0,0.5);
      
      var dang := Pi*2/c;
      var ang := -dang/2;
      
      var NextLine: (real,real, Painter)->real := (ang, dang, pnt)->
      begin
        
        var rx := Sin(ang);
        var ry := -Cos(ang);
        
        pnt.DrawLine(
          500 + iR*rx, 500 + iR*ry,
          500 +  R*rx, 500 +  R*ry,
          0,0,0,0.5
        );
        
        Result := ang + dang;
        
      end;
      
      var NextImage: procedure := ()->
      begin
        
      end;
      
      var enm: IEnumerator<CircleMenuData> := sub_menus.Select(t->t[1]).GetEnumerator();
      
      if not enm.MoveNext then exit;
      ang := NextLine(ang,dang, pnt);
      NextImage;
      
      ang := NextLine(ang,dang, pnt);
      if not enm.MoveNext then exit;
      
      while enm.MoveNext do
      begin
        ang := NextLine(ang,dang, pnt);
        NextImage;
      end;
      
      if c>sub_menus.Count then NextLine(ang,dang, pnt);
    end;
    
  end;

end.