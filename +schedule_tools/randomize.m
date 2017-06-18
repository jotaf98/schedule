function args = randomize(args, rng)
%RANDOMIZE
%   Replace any randomization ranges with uniformly sampled values.
%
%   Joao F. Henriques, 2017

  for i = 2:2:numel(args)
    a = args{i};
    if isnumeric(a) && numel(a) == 2
      args{i} = rng.rand() * abs(diff(a)) + min(a);
    end
  end
end

