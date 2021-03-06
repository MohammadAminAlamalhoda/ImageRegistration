% this function calculates ration of nonpositive elements of jacobian
% matrix of displacmentf field to number of all elements
function out = JacobianMatCalc(DisplacemnetField)
    save DisplacemnetField.mat DisplacemnetField
    pythonFunction = py.importlib.import_module('jacobian_determinant');
    pythonFunction.jacobian_calc.feval;
    tmp = load('jacobian_mat.mat');
    tmp = tmp.jacobian_mat;
    [row,~] = find(tmp<=0);
    out = length(row)/length(tmp);