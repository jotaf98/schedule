# Schedule
This is a scheduler that makes it easy to perform many runs/experiments in MatConvNet (and Matlab in general), with different parameters.

It has a flexible syntax for defining parameters, which allows grid searches, random searches, simple lists of parameter combinations, and any combinations thereof.

If multiple GPUs are present, `schedule` can intelligently assign one to each experiment in parallel, making sure that no GPU is left idle, as much as possible. Internally, this is implemented using `parfor`.


## Basics

Say you want to determine the best learning rate for the MNIST example (`<matconvnet>/examples/mnist/cnn_mnist.m`). From MatConvNet version 25 onwards, you can use the syntax:

`cnn_mnist('train.gpus', 1, 'train.learningRate',0.001, 'expDir', 'results/lr-0.001/')`

This runs MNIST training with the given learning rate, using GPU #1, and stores the results in the `results/lr-0.001` folder.

Testing many parameter combinations one-by-one can be tedious. Using `schedule`, 3 different learning rates can be tried at once:

`schedule(@cnn_mnist, '-dir', 'results/', '-gpus', 1, 'train.learningRate', {0.01, 0.001, 0.0001})`

The results will be stored in different folders, with names reflecting the particular parameter combination:

`results/train.learningRate=0.01
results/train.learningRate=0.001
results/train.learningRate=0.0001`

## Parallel training in multiple GPUs

Scheduling the same experiments in parallel across multiple GPUs (e.g. GPUs #1-#4) is as simple as using the option `'-gpus', 1:4`.

## Grid searches

More parameters can be added, resulting in all possible combinations being run:

`schedule(@cnn_mnist, '-dir', 'results/', '-gpus', 1, 'train.learningRate', {0.01, 0.001, 0.0001}, 'batchNormalization', {true, false})`

Nesting cell arrays with different choices results in them being expanded as part of the grid search, which can be used to craft more complicated combinations (see `help schedule` for more details).

## Random searches

Adding the option `'-random', N` will run N random combinations, instead of all of them (which would amount to a grid search).

In this case, it is also possible to specify that some parameters should be drawn from a uniform distribution over a range [A, B]. Instead of a list of choices given in a cell array, specify the range of the uniform distribution as a 2-elements vector:

`schedule(@cnn_mnist, '-dir', 'results/', '-gpus', 1, '-random', 100, 'train.learningRate', [0.01, 0.0001], 'batchNormalization', {true, false})`

## Documentation

Type `help schedule` at the Matlab console for the full documentation.

Joao F. Henriques, 2017
