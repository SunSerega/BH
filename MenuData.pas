﻿unit MenuData;

uses GData;

type
  
  ///Base type of Menu<MenuDataT>
  MenuBase = abstract class
    
    protected _owner, curr_child: MenuBase;
    protected progress, prog_dir: integer;
    
    
    
    public property Owner: MenuBase read _owner;
    
    public property DataObjectOf[m: MenuBase]: object read write; abstract;
    
    public procedure DrawOn(dx,dy: real; pnt: Painter); abstract;
    
    
    
    public static event UnProcessedEsc: procedure;
    
  end;
  
  ///BH Menu type
  Menu<SubMenuDataT> = abstract class(MenuBase)
    
    protected sub_menus := new Dictionary<MenuBase, SubMenuDataT>;
    
    public procedure AddMenu(m: MenuBase; data: SubMenuDataT) :=
    sub_menus.Add(m, data);
    
    public procedure RemoveMenu(m: MenuBase) :=
    sub_menus.Remove(m);
    
    public property MenuBase.DataObjectOf[m: MenuBase]: object read sub_menus[m] write sub_menus[m] := SubMenuDataT(value); override;
    
    public property MenuBase.DataOf[m: MenuBase]: SubMenuDataT read sub_menus[m] write sub_menus[m] := value; default;
    
  end;
  
  DummyMenu = class(Menu<byte>)
    
    public procedure DrawOn(dx,dy: real; pnt: Painter); override := exit;
    
  end;
  
  ///Menu in which all sub-menu's placed in circle
  CircleMenu = class(Menu<Painter>)
    
    public const R=450;
    public const iR=150;
    public const MinMenus=6;
    
    
    
    public procedure AddMenu(m: MenuBase; data: Image) :=
    sub_menus.Add(m, new Painter(data));
    
    public procedure DrawOn(dx,dy: real; pnt: Painter); override;
    begin
      
      pnt.DrawCircle;
      pnt.DrawCircle;
      
      var dang := Pi*2/Max(MinMenus,sub_menus.Count);
      var ang := -dang/2;
      
      var NextLine: procedure := ()->
      begin
        
        var rx := Sin(ang);
        var ry := -Cos(ang);
        pnt.DrawLine(
          500 + iR*rx, 500 + iR*ry,
          500 +  R*rx, 500 +  R*ry,
          0,0,0,1
        );
        
        ang += dang;
      end;
      
      var NextImage: procedure := ()->
      begin
        
      end;
      
      var enm: IEnumerator<Painter> := sub_menus.Values.GetEnumerator();
      
      if not enm.MoveNext then exit;
      NextLine;
      NextImage;
      
      NextLine;
      if not enm.MoveNext then exit;
      NextImage;
      
      while enm.MoveNext do
      begin
        NextLine;
        NextImage;
      end;
      
      if sub_menus.Count < MinMenus then NextLine;
    end;
    
  end;

end.