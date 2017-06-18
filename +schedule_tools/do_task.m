function [err, outputs] = do_task(func, tasks_dir, common_args, args, ...
  process_to_gpu, t, gpu_arg_name, dir_arg_name, ignore_errors)
%DO_TASK
%   Execute a single task. A GPU may be assigned depending on the worker
%   process, and any errors are collected.
%
%   Joao F. Henriques, 2017

  process = getCurrentTask();
  if isempty(process)  % running outside a parfor, only 1 process
    process = 1;
  else
    process = process.ID;
  end

  gpu = process_to_gpu(process);
  if gpu == 0  % CPU mode
    gpu = [];
  end

  % only specific args to compose directory name
  dir_name = schedule_tools.task_to_string(args, false);
  
  % full args to help debug
  full_name = schedule_tools.task_to_string([common_args, args], true);

  fprintf('\nStarting task #%i in process #%i: %s\n\n', t, process, full_name);

  err = [];
  outputs = cell(1, nargout(func));
  
  all_args = [{dir_arg_name, [tasks_dir '/' dir_name], ...
    gpu_arg_name, gpu}, common_args, args];
  
  % call the function
  if ~isempty(ignore_errors) && ~ignore_errors
    [outputs{:}] = func(all_args{:});
  else
    try
      [outputs{:}] = func(all_args{:});
    catch e
      % return error report
      err = e.getReport('extended', 'hyperlinks', 'off');
      err = sprintf('#%i: %s\n%s\n', t, full_name, err);
    end
  end
end