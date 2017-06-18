function str = task_to_string(args, use_spaces)
%TASK_TO_STRING
%   Compose task a string (e.g. to compose directories) from the arguments
%   list.
%
%   Joao F. Henriques, 2017

  if use_spaces
    pattern = ', %s = %s';
  else
    pattern = ',%s=%s';
  end
  
  % convert name-value pairs
  str = cell(1, numel(args) / 2);
  for i = 1 : numel(args) / 2
    value = args{i * 2};
    
    if isnumeric(value) && numel(value) == 2
      % special case, a uniformly sampled random range
      value = sprintf('U(%g,%g)', min(value), max(value));
    else
      value = value_to_string(value);
    end
    
    str{i} = sprintf(pattern, args{i * 2 - 1}, value);
  end
  
  % concatenate into a single string and delete extraneous initial comma
  str = [str{:}];
  if ~isempty(str)
    if use_spaces
      str(1:2) = [];
    else
      str(1) = [];
    end
  end
end

function str = value_to_string(value)
  % convert an argument value to a string, to compose an experiment name
  % (must not contain invalid directory characters)
  if ischar(value)
    illegal = '<>:"/\|?*';  % replace illegal characters
    str = value;
    str(ismember(str, illegal) | str < 32) = '_';
  elseif isa(value, 'function_handle')
  	str = func2str(value);
  elseif isscalar(value)
    if islogical(value)
      value = double(value);
    end
    if isnumeric(value)
      str = num2str(value);
    else
      error('Unsupported value.');
    end
  elseif isempty(value)
    str = '[]';
  else
    error('Only numeric, string and function handle arguments are supported.');
  end
end
