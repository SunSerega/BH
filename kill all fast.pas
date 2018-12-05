begin
  try
    foreach var p in System.Diagnostics.Process.GetProcessesByName('BH') do
    try
      p.Kill;
      writeln('killed proc');
    except
      on e: Exception do
        writeln('error killing proc');
    end;
  except
    on e: Exception do
      writeln($'general error');
  end;
  readln;
end.