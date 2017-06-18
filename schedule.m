function schedule(func, varargin)
%SCHEDULE Schedule training with different parameters on multiple GPUs/CPUs
%   SCHEDULE(@TRAIN, '-dir', DIR, '-gpus', GPUS, 'PARAM1', VAL1, ...)
%   Schedules training tasks by calling TRAIN with different parameter
%   combinations, given as name-value pairs ('PARAM1', VAL1, 'PARAM2',
%   VAL2, ...). By default a grid search is performed, but a random search
%   is also possible (see below).
%
%   TRAIN is your main training function, that takes its parameters as
%   name-value pairs (e.g. parsed with MatConvNet's VL_ARGPARSE).
%
%   DIR is the root directory where all experiment outputs will be stored.
%
%   GPUS is either a single GPU index (to run tasks sequentially), or
%   multiple indexes (to distribute tasks automatically across GPUs, in
%   parallel).
%
%   The names 'PARAM1', 'PARAM2', etc may be arbitrary, while VAL1, VAL2,
%   etc each specify a list of parameters to try.
%
%   If needed, more complex parameter combinations can be recursively
%   nested using cell arrays; see example below for details.
%
%   In addition to your custom parameters, the following are also passed
%   to TRAIN:
%   - 'expDir': The unique experiment directory for each parameter
%     combination, obtained by appending a unique string to DIR.
%   - 'train.gpus': The GPU index to be used in the experiment.
%
%
%   Example 1:
%    Suppose you have a training function that takes the following syntax
%    (by using vl_argparse):
%
%     train('alpha',1, 'beta','X', 'train.gpus',1, 'expDir', '/data/exp1');
%
%    Then you can perform a grid search over more parameters with:
%
%     schedule(@train, '-dir', '/data/exp1', '-gpus', 1, ...
%       'alpha', 1:5, 'beta', {'X', 'Y'});
%
%    Distributing the workload in parallel over GPUS #1 to #4:
%
%     schedule(@train, '-dir', '/data/exp1', '-gpus', 1:4, ...
%       'alpha', 1:5, 'beta', {'X', 'Y'});
%
%
%   Example 2:
%    Using a list of parameter combinations to try, instead of a grid
%    search:
%
%     schedule(@train, '-dir', '/data/exp1', '-gpus', 1, ...
%       {{'alpha', 1}, {'beta', 'X'}});
%
%    This will run 2 tasks, one with alpha=1, the other with beta='X'.
%
%    Because lists of arguments lists are expanded automatically, this can
%    be used to express more complex combinations of parameters succintly:
%
%     schedule(@train, '-dir', '/data/exp1', '-gpus', 1, ...
%       {{'beta', 'X'}, {'beta', 'Y', 'alpha', 1:3}});
%
%    This runs 4 tasks, one with beta='X', and other 3 tasks with beta='Y'
%    and an additional argument alpha taking the values 1 to 3.
%
%
%   SCHEDULE(..., '-random', R)
%   Performs a random search instead of grid search, by executing R tasks
%   chosen at random. This is essentially a random subset of the grid
%   search.
%
%   In this mode, it is possible to specify name-value pairs where the
%   value a vector of 2 numbers [LOWER, UPPER], denoting the range for a
%   uniformly sampled random value.
%
%
%   Example 3:
%     schedule(@train, '-random', 50, '-dir', '/data/exp1', '-gpus', 1, ...
%       'alpha', [0, 5], 'beta', {'X', 'Y'});
%
%    This would call @train 50 times, with random choices of 'beta', and
%    'alpha' randomly sampled from the interval 0 to 5, uniformly.
%
%
%   SCHEDULE(..., '-cpus', N)
%   Does the same, but over N CPUs. The only difference is that there will
%   be N processes running in parallel, and the 'train.gpus' argument will
%   always be [].
%
%
%   Joao F. Henriques, 2017

  % argument name of experiment dir (e.g. 'expDir', '/data/test1/a=5,b=20')
  dir_arg_name = 'expDir';
  
  % argument name of GPU index (e.g. 'train.gpus', 1)
  gpu_arg_name = 'train.gpus';
  

  if isempty(func)  % test function
    func = @test_function;
  end
  
  % parse special options (starting with -)
  [tasks_dir, varargin] = schedule_tools.parse_option(varargin, '-dir');
  [gpus, varargin] = schedule_tools.parse_option(varargin, '-gpus');
  [cpus, varargin] = schedule_tools.parse_option(varargin, '-cpus');
  [random_iters, varargin] = schedule_tools.parse_option(varargin, '-random');
  [ignore_errors, varargin] = schedule_tools.parse_option(varargin, '-ignoreerrors');
  
  assert(~isempty(tasks_dir), 'Must specify -dir option.');
  
  assert(xor(isempty(gpus), isempty(cpus)), ...
    'Must specify either -gpus or -cpus option.');
  
  % 'process_to_gpu' will be 0 for CPU processes and the respective index
  % for GPUs
  if ~isempty(gpus)
    assert(isvector(gpus) && all(round(gpus) == gpus) && all(gpus > 0), ...
      '-gpus option must be a list of GPU indexes.');
    process_to_gpu = gpus;
  else
    assert(isscalar(cpus) && round(cpus) == cpus && cpus > 0, ...
      '-cpus option must be the number of CPU processes.');
    process_to_gpu = zeros(cpus, 1);
  end
  
  
  % parse nested arguments to a single list of tasks
  [tasks, common_args] = schedule_tools.parse_tasks(varargin, ~isempty(random_iters));
  
  
  % display tasks and processes lists
  if isempty(gpus)
    kind = 'CPU';
  else
    kind = 'GPU';
  end
  if numel(process_to_gpu) > 1
    kind(end+1) = 's';
  end
  fprintf('Scheduling tasks for experiment %s (%s), on %i %s', ...
    func2str(func), tasks_dir, numel(process_to_gpu), kind);
  if ~isempty(gpus)
    fprintf(' (');
    for i = 1:numel(gpus)
      fprintf('%i ', gpus(i));
    end
    fprintf('\b)');
  end
  fprintf('.\n');
  for t = 1:numel(tasks)
    fprintf('#%i: %s\n', t, schedule_tools.task_to_string([common_args, tasks{t}], true));
  end
  
  if isempty(random_iters)
    errors = cell(size(tasks));
  else
    errors = cell(1, random_iters);
  end
  
  % set up random number generator that doesn't affect the global one
  rng = RandStream('mt19937ar', 'Seed', 'shuffle');
  
  % execute tasks
  if numel(process_to_gpu) <= 1
    % one process (1 GPU or 1 CPU), execute sequentially
    if isempty(random_iters)
      % execute all tasks
      for t = 1:numel(tasks)
        errors{t} = schedule_tools.do_task(func, tasks_dir, common_args, tasks{t}, ...
          process_to_gpu, t, gpu_arg_name, dir_arg_name, ignore_errors);
      end
    else
      % randomly select task, and randomize arguments if needed
      for i = 1:random_iters
        t = rng.randi(numel(tasks));
        args = schedule_tools.randomize(tasks{t}, rng);
        
        errors{i} = schedule_tools.do_task(func, tasks_dir, common_args, args, ...
          process_to_gpu, t, gpu_arg_name, dir_arg_name, ignore_errors);
      end
    end
    
  else
    % initialize parallel pool if necessary, one parfor worker per process
    p = gcp('nocreate');
    if ~isempty(p) && p.NumWorkers ~= numel(process_to_gpu)
      delete(p);
      p = [];
    end
    if isempty(p)
      parpool(numel(process_to_gpu));
    end
    
    % execute in parallel
    if isempty(random_iters)
      % execute all tasks
      parfor t = 1:numel(tasks)
        errors{t} = schedule_tools.do_task(func, tasks_dir, common_args, tasks{t}, ...
          process_to_gpu, t, gpu_arg_name, dir_arg_name, ignore_errors);  %#ok<*PFBNS>
      end
    else
      % randomly select task, and randomize arguments if needed
      parfor i = 1:random_iters
        t = rng.randi(numel(tasks));
        args = schedule_tools.randomize(tasks{t}, rng);
        
        errors{i} = schedule_tools.do_task(func, tasks_dir, common_args, args, ...
          process_to_gpu, t, gpu_arg_name, dir_arg_name, ignore_errors);
      end
    end
  end
  
  % display errors, if any
  if ~all(cellfun('isempty', errors))
    fprintf('\n\nCaught errors:\n\n');
    for t = find(~cellfun('isempty', errors(:)'))
      name = schedule_tools.task_to_string([common_args, tasks{t}], true);
      fprintf('#%i: %s\n%s\n', t, name, errors{t});
    end
  end

end

function test_function(varargin)
  % test function for debugging
  fprintf('Starting: '); disp(varargin);
  pause(1);
  fprintf('Finishing: '); disp(varargin);
end

