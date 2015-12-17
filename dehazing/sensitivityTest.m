function sensitivityTest(varFactor)

beta = 6;  % constant multiplier to priorpenelty(t(x)) in objective function
gamma = 0.3; % constant multiplier to priorpenelty(J(x)) in objective function
delta = 1; % weight for the Dark Channel Prior

% varFactor = 0.1;
nSamples = 50;

a = zeros(nSamples, 1);

for i=1:nSamples
    
    disp(i);
    
    beta_n = beta + varFactor*beta*randn;
    gamma_n = gamma + varFactor*gamma*randn;
    delta_n = beta + varFactor*delta*randn;
    
    [aSample, ~, ~, ~, ~] = main(beta_n, gamma_n, delta_n);
    
    a(i) = aSample;

end

save(strcat('a_', num2str(varFactor), '.mat')', 'a');

end