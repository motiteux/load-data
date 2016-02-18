function [G_red, x_red, b_red] = snow_gis_reduce(G, x, b)
%SNOW_GIS_REDUCE enforces the graph generated by SNOW_GIS() to consist of
%only the cholera and pump nodes, discarding the road nodes. The distances
%between nodes are adapted to this new setting.
%
%   Usage:
%       [G_red, x_red, b_red] = snow_gis_reduce(G, x, b)
%
%   Input:
%       G   : A Matlab structure encoding graph information.
%       x   : A vector with non-zero entry at the location of the infected
%             water pump.
%       b   : A vector with whose entries represent the observed death 
%             count by cholera at each point.
%
%   Output:
%       G_red   : A Matlab structure encoding graph information.
%       x_red   : A vector with non-zero entry at the location of the infected
%                 water pump.
%       b_red   : A vector with whose entries represent the observed death 
%                 count by cholera at each point.

%   Example:
%       [G_red, x_red, b_red] = snow_gis_reduce(G, x, b)
%
%   Requires: GSPBox (https://lts2.epfl.ch/gsp/)
%             MatlabBGL (http://dgleich.github.io/matlab-bgl/)
%
%   Reference: http://blog.rtwilson.com/john-snows-famous-cholera-analysis-data-in-modern-gis-formats/
%
% Author: Rodrigo Pena (rodrigo.pena@epfl.ch)
% Date: 15 Feb 2016

%% Parse input
assert(isfield(G,'N') && isfield(G, 'W') && isfield(G, 'Dist') && ...
    isfield(G, 'idx_cholera') && isfield(G, 'idx_pump') && ...
    isfield(G, 'coords'), ...
    'G does not have the required fields');

assert(length(x) == G.N, 'x must be of length G.N');

assert(length(b) == G.N, 'b must be of length G.N');

%% Initialization
idx_non_road = [G.idx_cholera, G.idx_pump];
N_red = length(idx_non_road);
Dist_red = sparse(zeros(G.N, N_red));

%% Compute shortest path distances
for i = 1:N_red
    Dist_red(:, i) = shortest_paths(G.Dist, idx_non_road(i));
end
Dist_red = Dist_red(idx_non_road, :);

%% Compute new weight matrix
%TODO: check if graph generated by Vassilis' graph learning code works
% W = gsp_learn_graph_log_degrees(Dist_red.^2, 1, 1, struct('verbosity', 1, 'maxit', 5000));
% W = gsp_learn_graph_log_degrees(Dist_red.^2, 10, 1, struct('verbosity', 1, 'maxit', 5000));

sigma = sum(sum(triu(G.Dist).^2))./nnz(triu(G.Dist));
[spi, spj, dist] = find(Dist_red);
W = sparse(spi, spj, double(exp(-dist.^2/sigma)), N_red, N_red);
W(1:(N_red + 1):end) = 0;  % Remove values in the main diagonal
W = gsp_symmetrize(W, 'average');

%% Create Graph structure
G_red = struct( 'N', N_red, ...
                'W', W, ...
                'coords', G.coords(idx_non_road, :), ...
                'type', 'nearest neighbors');

%% Retain only the main connected component
[G_cell, node_cell] = connected_subgraphs(G_red);
G_red = G_cell{1};
nodes = node_cell{1};

%% Update Graph structure
G_red.sigma = sigma;
G_red.Dist = Dist_red(nodes, nodes);
G_red.idx_cholera = nodes(nodes <= length(G.idx_cholera));
G_red.idx_cholera = 1:length(G_red.idx_cholera);
G_red.idx_pump = nodes(nodes > length(G.idx_cholera));
G_red.idx_pump = (length(G_red.idx_cholera) + 1):G_red.N;
G_red = gsp_graph_default_parameters(G_red);

%% Update signals
x_red = x(idx_non_road);
x_red = x_red(nodes);
b_red = b(idx_non_road);
b_red = b_red(nodes);

end