function [option, args] = parse_option(args, name)
%PARSE_OPTION
%   Find a special option and return its value, removing it from the list.
%   If not found, empty is returned.
%
%   Joao F. Henriques, 2017

  found = find(strcmp(args(1:2:end-1), name));
  
  option = [];
  if isscalar(found)
    found = found * 2 - 1 ;  % because strcmp searches over half the list
    option = args{found + 1};
    args(found:found+1) = [];  % remove from list
  end
end

