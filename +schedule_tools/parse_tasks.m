function [tasks, common_args, task_to_string_fn, do_task_fn] = ...
  parse_tasks(args, is_random)
%PARSE_TASKS
%   Parses nested arguments into a single list of tasks.
%
%   Joao F. Henriques, 2017


  % now parse the tasks into a single list of arguments lists
  tasks = parse_args(args, {}, {}, is_random);
  
  
  % some parameters do not change; collect them separately in common_args,
  % to get more compact directory names. exclude randomized parameters.
  ref_names = tasks{1}(1:2:end-1);  % all parameters will be compared to the first task's
  ref_values = tasks{1}(2:2:end);
  
  unchanged = true(1, numel(ref_names));  % whether each has different values between tasks
  for i = 1:numel(ref_values)  % randomized parameters always change
    if isnumeric(ref_values{i}) && numel(ref_values{i}) == 2
      unchanged(i) = false;
    end
  end
  
  for t = 2:numel(tasks)  % iterate other tasks
    names = tasks{t}(1:2:end-1);
    values = tasks{t}(2:2:end);
    for ref_idx = find(unchanged)  % iterate arguments of the reference task that are unchanged so far
      idx = find(strcmp(names, ref_names{ref_idx}), 1);  % find same argument in this task
      if ~isempty(idx) && ~isequal(values{idx}, ref_values{ref_idx})  % value is different from reference
        unchanged(ref_idx) = false;
      end
    end
  end
  
  % gather common arguments
  common_args = reshape([ref_names(unchanged); ref_values(unchanged)], 1, []);
  
  % remove unchanging parameters
  unchanged_names = ref_names(unchanged);
  for t = 1:numel(tasks)
    to_remove = ismember(tasks{t}(1:2:end-1), unchanged_names);  % find matching names
    to_remove = repelem(to_remove, 1, 2);  % remove both names and values
    tasks{t}(to_remove) = [];
  end
  
  
  % return function handles
  task_to_string_fn = @task_to_string;
  do_task_fn = @do_task;
end

function tasks = parse_args(args, curr_task, tasks, is_random)
  for i = 1:numel(args)
    a = args{i};
    
    if iscell(a) || (isnumeric(a) && isvector(a) && numel(a) > 1)
      % an enumeration of choices, either as cell array or numeric vector.
      
      if is_random
        % special case: 2-elements numeric vectors (random search limits),
        % leave as-is.
        if ~iscell(a)
          assert(numel(a) == 2, ['For random search, any arguments that are numeric' ...
            ' vectors must have 2 elements (the limits of a uniform distribution).']);
          continue
        end
      end
      
      % general case (enumeration of choices)
      tasks = parse_choices(a, args(i+1:end), [curr_task, args(1:i-1)], tasks, is_random);
      return
    end
  end
  
  % made it to the end of a branch, validate and add complete task to list
  curr_task = [curr_task, args];
  if mod(numel(curr_task), 2) ~= 0 || ~iscellstr(curr_task(1:2:end-1))
    error('Each task''s arguments must consist of name-value pairs. Found arguments:\n%s', ...
      evalc('disp(curr_task)'));
  end
  tasks{end+1} = curr_task;
end

function tasks = parse_choices(choices, args, curr_task, tasks, is_random)
  if ~iscell(choices)  % convert vector to cell array
    choices = num2cell(choices);
  end
  
  % branch out for each possibility
  for j = 1:numel(choices)
    c = choices{j};
    if ~iscell(c)
      c = {c};
    end
    
    tasks = parse_args([c, args], curr_task, tasks, is_random);
  end
end

