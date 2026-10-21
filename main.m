
%% GLOBAL SETTINGS

% Save all figures after they have been displayed
SAVE = true;

% Colors
g = gray(256);
mygray = g(1:240, :); % Grayscale without the near-white end

% 5-step grayscale for the quintile choropleth maps (light -> dark)
my_step_colormap = [
    247, 247, 247;
    204, 204, 204;
    150, 150, 150;
     99,  99,  99;
     37,  37,  37
] / 255;

% Font size used in all figures
myfontsize = 15;

% West German states shown in the state-level charts
land_names = {
    'Schleswig-Holstein', 'Hamburg', 'Bremen', 'Niedersachsen', ...
    'Nordrhein-Westfalen', 'Hessen', 'Rheinland-Pfalz', 'Baden-Württemberg', ...
    'Bayern'};

%% READ BRIDGE DATA

% bridge.csv maps census county IDs to IPUMS county IDs (KREIS_KENN).
% IDs are read as strings to keep leading zeros and spaces intact.
file = 'bridge.csv';

opts = detectImportOptions(file, 'TextType', 'string');

opts = setvartype(opts, {'census_id', 'ipums_id'}, 'string');

opts.SelectedVariableNames = {'census_id', 'ipums_id'};

bridge = readtable(file, opts);

% County shapes from IPUMS (state of 1950)
shapes_ipums = readgeotable('germany_ipums/niemcy_1949_1989/Germany_1950_v.1.0.shp');

%% READ EXPELLEE POPULATION

% Table 6: total population and number of expellees per county (13.09.1950).
% Data starts at column D (County ID).
file = 'sources/tab6vz1950population-expellees.xlsx';

opts = detectImportOptions(file, 'Sheet', 2, ...
    'VariableNamesRange', '', ...
    'DataRange', 'D4', ...
    'VariableNamingRule', 'preserve', ...
    'TextType', 'string');

opts.VariableNames = {'county_id', 'county_name', 'total_population', 'total_expellees'};

expellee_population = readtable(file, opts);

expellee_population = add_lindau(expellee_population);

expellee_population_ipums = get_ipums_table(expellee_population, bridge, shapes_ipums);

%% READ 1939 RESIDENCY

% Table 7: 1950 population by place of residence on 1 September 1939.
% The header spans two rows: row 2 holds main categories, row 3 holds
% sub-categories.
file = 'sources/tab7vz1950population-by-place-of-residence-on-september-1-1939-org.xlsx';

raw_headers = readcell(file, 'Sheet', 2, 'Range', '2:3');

h0 = {'county_id', 'county_name'};
h1 = string(raw_headers(1, :));
h2 = string(raw_headers(2, :));

% Use the sub-category name if present, otherwise the main category name
for i = (1:length(h2))
    if ismissing(h2(i))
        h2(i) = h1(i);
    end
end

h2 = [h0, h2];

opts = detectImportOptions(file, 'Sheet', 2, ...
    'VariableNamesRange', '', ...
    'DataRange', 'D7', ...
    'VariableNamingRule', 'preserve', ...
    'TextType', 'string');

opts.VariableNames = h2;

% Selected columns
opts.SelectedVariableNames = {
    'county_id', 'county_name', ...
    'in the same State', 'in another state of the Federal Republic', ...
    'in Berlin', 'in another state of the Soviet Occupation Zone', ...
    'in the German eastern territories under foreign administration and in the Saar region', ...
    'Silesia', 'Brandenburg', 'Pommerania', 'East Prussia', 'Saar region' ...
    ...
    'abroad', 'Austria', 'Czechoslovakia', 'Poland', 'Gdansk', 'Switzerland', ...
    'Soviet Union', 'former Baltic States', 'former Memel Territory', 'Hungary', ...
    'Yugoslavia', 'Romania', 'Italy', 'France', 'Belgium', 'Netherlands', ...
    'Luxembourg', 'Great Britain', 'Denmark', ...
    ...
    'non European States', 'Chian and Japan', 'USA', 'Canada', 'Brazil', ...
    'Argentinia', 'South African Union', 'Australia', 'Oceania'
};

population_1939 = readtable(file, opts);

% Replacement names
population_1939.Properties.VariableNames = {
    'county_id', 'county_name', ...
    'same_state', 'another_state', 'berlin', 'gdr', 'east_admin_and_saar', ...
    'silesia', 'brandenburg', 'pomerania', 'east_prussia', 'saar'...
    ...
    'abroad', 'austria', 'czechoslovakia', 'poland', 'gdansk', 'switzerland', ...
    'soviet_union', 'former_baltic_states', 'former_memel_territory', 'hungary', ...
    'yugoslavia', 'romania', 'italy', 'france', 'belgium', 'netherlands', ...
    'luxembourg', 'great_britain', 'denmark', ...
    ...
    'non_european_states', 'china_and_japan', 'usa', 'canada', 'brazil', ...
    'argentina', 'south_african_union', 'australia', 'oceania'
};

population_1939 = add_lindau(population_1939);

population_1939_ipums = get_ipums_table(population_1939, bridge, shapes_ipums);

%% READ WAR DESTRUCTION

% Table 16: normal dwellings in total and those affected by war damages (1950).
% Absolute counts are read (not the source's share column), so that Lindau
% can be added to Bayern before the share is computed.
file = 'sources/tab16gz1950war-destructions.xlsx';

opts = detectImportOptions(file, 'Sheet', 2, ...
    'VariableNamesRange', 'A2', ...
    'DataRange', 'A4', ...
    'VariableNamingRule', 'preserve', ...
    'TextType', 'string');

opts.SelectedVariableNames = { ...
    'County ID', 'County Name', 'Normal dwellings (total)', ...
    'Normal dwellings affected by war damages'};

war_destruction = readtable(file, opts);

war_destruction.Properties.VariableNames = { ...
    'county_id', 'county_name', 'total_dwellings', 'damaged_dwellings'};

war_destruction = add_lindau(war_destruction);

% Share of damaged dwellings in %
war_destruction.damaged_percentage = ...
    war_destruction.damaged_dwellings ./ war_destruction.total_dwellings .* 100;

war_destruction_ipums = get_ipums_table(war_destruction, bridge, shapes_ipums);

%% PREPARE DATA FOR CHARTS

% State-level rows (one per Land, in the order of land_names)
state_expellees = get_state_rows(expellee_population, land_names);
state_1939 = get_state_rows(population_1939, land_names);

% Add the 1950 total population to the 1939 residency table,
% it is the denominator for all residency maps
county_population = expellee_population(:, {'county_id', 'total_population'});

population_1939_ipums = innerjoin(population_1939_ipums, county_population, ...
    'Keys', 'county_id');

%% BAR CHART: EXPELLEES VS. NATIVE POPULATION PER STATE

% Native population = total population minus expellees
expellees = state_expellees.total_expellees;
native = state_expellees.total_population - expellees;
states = state_expellees.county_name;

% Sort states by the number of expellees
[sorted_expellees, idx] = sort(expellees, "descend");

sorted_native = native(idx);
sorted_states = cellstr(states(idx));

plot_data = [sorted_native, sorted_expellees];

% Chart
fig = figure();

b = barh(sorted_states, plot_data, 'grouped');

xlabel('Population');
ylabel("State")

legend({'Native population', 'Expellees'}, 'Location', 'northeast');

title('Expellees vs. native population (1950)');

set(gca, 'XGrid', 'on');

xlim([0, 13500000]);
xticks(0:3000000:15000000)

% Value labels for series 1 (native population)
xtips = b(1).YEndPoints + 0.005 * max(xticks); % Small shift to the right
ytips = b(1).XEndPoints;
labels = string(b(1).YData);
text(xtips, ytips, labels, 'HorizontalAlignment','left', ...
    'VerticalAlignment','middle','FontSize',8);

% Value labels for series 2 (expellees)
xtips = b(2).YEndPoints + 0.005 * max(xticks); % Small shift to the right
ytips = b(2).XEndPoints;
labels = string(b(2).YData);
text(xtips, ytips, labels, 'HorizontalAlignment','left', ...
    'VerticalAlignment','middle','FontSize',8);

fontsize(fig, myfontsize, "points")


%% MAP: MIGRATION FROM OTHER WEST GERMAN STATES

col = 'another_state';

% Share of the 1950 population in %
base = population_1939_ipums(:, {'Shape', col});
base{:, col} = base{:, col} ./ population_1939_ipums.total_population .* 100;

% Class edges
values = base{:, col};
edges = quantile(values, linspace(0, 1, 6));

% Separate edges for binning, open at both ends (keeps -Inf/Inf out of the labels)
bin_edges = edges;
bin_edges(1) = -Inf;
bin_edges(end) = Inf;

% Assign each county to a class 1-5
base.color_class = discretize(values, bin_edges);

% Figure
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'color_class');
geobasemap(gx, 'none');
gx.Grid = 'off';
gx.Visible = 'off';

% Colors
colormap(gx, my_step_colormap);

% Color limits at x.5, so that classes 1-5 fall in the middle of each color
clim(gx, [0.5, 5.5]);

% Colorbar
cb = colorbar;

% 6 ticks placed exactly on the class boundaries
cb.Ticks = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5];

% Label the ticks with all 6 real edges (min to max), not the -Inf/Inf ones
cb.TickLabels = string(round(edges, 2));

% Title and formatting
t = title('Migration from other West German states');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");


%% MAP: MIGRATION FROM EAST GERMANY (SOVIET ZONE)

col = 'gdr';

% Share of the 1950 population in %
base = population_1939_ipums(:, {'Shape', col});
base{:, col} = base{:, col} ./ population_1939_ipums.total_population .* 100;

% Class edges
values = base{:, col};
edges = quantile(values, linspace(0, 1, 6));

% Separate edges for binning, open at both ends (keeps -Inf/Inf out of the labels)
bin_edges = edges;
bin_edges(1) = -Inf;
bin_edges(end) = Inf;

% Assign each county to a class 1-5
base.color_class = discretize(values, bin_edges);

% Figure
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'color_class');
geobasemap(gx, 'none');
gx.Grid = 'off';
gx.Visible = 'off';

% Colors
colormap(gx, my_step_colormap);

% Color limits at x.5, so that classes 1-5 fall in the middle of each color
clim(gx, [0.5, 5.5]);

% Colorbar
cb = colorbar;

% 6 ticks placed exactly on the class boundaries
cb.Ticks = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5];

% Label the ticks with all 6 real edges (min to max), not the -Inf/Inf ones
cb.TickLabels = string(round(edges, 2));

% Title and formatting
t = title('Migration from East Germany');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");


%% MAP: MIGRATION FROM BERLIN

col = 'berlin';

% Share of the 1950 population in %
base = population_1939_ipums(:, {'Shape', col});
base{:, col} = base{:, col} ./ population_1939_ipums.total_population .* 100;

% Class edges
values = base{:, col};
edges = quantile(values, linspace(0, 1, 6));

% Separate edges for binning, open at both ends (keeps -Inf/Inf out of the labels)
bin_edges = edges;
bin_edges(1) = -Inf;
bin_edges(end) = Inf;

% Assign each county to a class 1-5
base.color_class = discretize(values, bin_edges);

% Figure
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'color_class');
geobasemap(gx, 'none');
gx.Grid = 'off';
gx.Visible = 'off';

% Colors
colormap(gx, my_step_colormap);

% Color limits at x.5, so that classes 1-5 fall in the middle of each color
clim(gx, [0.5, 5.5]);

% Colorbar
cb = colorbar;

% 6 ticks placed exactly on the class boundaries
cb.Ticks = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5];

% Label the ticks with all 6 real edges (min to max), not the -Inf/Inf ones
cb.TickLabels = string(round(edges, 2));

% Title and formatting
t = title('Migration from Berlin');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");


%% MAP: MIGRATION FROM THE EASTERN TERRITORIES AND THE SAAR REGION

col = 'east_admin_and_saar';

% Share of the 1950 population in %
base = population_1939_ipums(:, {'Shape', col});
base{:, col} = base{:, col} ./ population_1939_ipums.total_population .* 100;

sorted_1939 = sort(base{:, col}, 'descend');
upper_lim = sorted_1939(2);

% Class edges
values = base{:, col};
edges = quantile(values, linspace(0, 1, 6));

% Separate edges for binning, open at both ends (keeps -Inf/Inf out of the labels)
bin_edges = edges;
bin_edges(1) = -Inf;
bin_edges(end) = Inf;

% Assign each county to a class 1-5
base.color_class = discretize(values, bin_edges);

% Figure
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'color_class');
geobasemap(gx, 'none');
gx.Grid = 'off';
gx.Visible = 'off';

% Colors
colormap(gx, my_step_colormap);

% Color limits at x.5, so that classes 1-5 fall in the middle of each color
clim(gx, [0.5, 5.5]);

% Colorbar
cb = colorbar;

% 6 ticks placed exactly on the class boundaries
cb.Ticks = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5];

% Label the ticks with all 6 real edges (min to max), not the -Inf/Inf ones
cb.TickLabels = string(round(edges, 2));

% Title and formatting
t = title('Migration from the eastern territories and the Saar region');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");


%% BAR CHART: MIGRATION FROM EAST GERMANY, BERLIN AND THE EASTERN TERRITORIES

% Columns of the eastern territories and their chart labels
east_cols = {'silesia', 'brandenburg', 'pomerania', 'east_prussia'};
east_labels = {'Silesia', 'Brandenburg (east)', 'Pomerania', 'East Prussia'};

% Totals over all states
east_sums = sum(state_1939{:, east_cols}, 1, 'omitnan');
berlin_sum = sum(state_1939.berlin, 'omitnan');
gdr_sum = sum(state_1939.gdr, 'omitnan');

% Sort the totals (ascending, so the largest bar is on top)
totals = [gdr_sum, berlin_sum, east_sums];
[sorted_totals, idx] = sort(totals);

% Labels in the same order as the totals
chart_labels = [{'East Germany', 'Berlin'}, east_labels];
sorted_labels = chart_labels(idx);

% Chart
fig = figure();

b = barh(sorted_totals);

yticks(1:length(sorted_labels));
yticklabels(sorted_labels);

set(gca, 'XGrid', 'on');

xlabel('Number of migrants');
title('Migration from East Germany, Berlin and the eastern territories');

% Value labels next to the bars
label_x = b.YEndPoints + 0.005 * max(xticks); % Small shift to the right
label_y = b.XEndPoints;

value_labels = string(sorted_totals);

text(label_x, label_y, value_labels, 'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'middle', 'FontSize', 8);

fontsize(fig, myfontsize, "points")


%% MAP: COUNTRIES OF ORIGIN NAMED IN THE CENSUS

% World borders valid in 1937 (CShapes 2.0)
world_gis = readgeotable('cshapes/CShapes-2.0.shp');
world_1937_gis = world_gis( ...
    world_gis.gwsyear <= 1937 & world_gis.gweyear >= 1937, :);

% All countries named in the census table
origin_countries = { ...
    'Austria', 'Czechoslovakia', 'Poland', 'Gdansk', ...
    'Switzerland', 'Soviet Union', 'Estonia', 'Latvia', ...
    'Lithuania', 'Hungary', 'Yugoslavia', 'Romania', ...
    'Italy', 'France', 'Belgium', 'Netherlands', ...
    'Luxembourg', 'Great Britain', 'Denmark', 'China', ...
    'Japan', 'USA', 'Canada', 'Brazil', ...
    'Argentina', 'South Africa', 'Australia', 'Germany' ...
};

% Some names differ in CShapes
census_names = {'Gdansk', 'Soviet Union', 'Romania', 'Italy', ...
    'Great Britain', 'USA'};
cshapes_names = {'Danzig', 'Russia (Soviet Union)', 'Rumania', ...
    'Italy/Sardinia', 'United Kingdom', 'United States of America'};
origin_countries_mapped = replace(origin_countries, census_names, cshapes_names);

% Select the shapes of the named countries
is_origin = ismember(world_1937_gis.cntry_name, origin_countries_mapped);
origin_gis = world_1937_gis(is_origin, :);

% Chart
fig = figure();

geoplot(world_1937_gis, 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', [0.8 0.8 0.8]);
hold on;

geoplot(origin_gis, 'FaceColor', '#D95319', 'EdgeColor', 'black');

title('Countries of origin named in the census (1937 borders)');

fontsize(fig, myfontsize, "points")


%% BAR CHART: MIGRATION FROM EUROPEAN COUNTRIES

% European columns and their chart labels (same order)
europe_cols = { ...
    'austria', 'czechoslovakia', 'poland', 'gdansk', 'switzerland', ...
    'soviet_union', 'former_baltic_states', 'former_memel_territory', ...
    'hungary', 'yugoslavia', 'romania', 'italy', 'rest_of_south_and_southeast_europe', ...
    'france', 'belgium', 'netherlands', 'luxembourg', 'great_britain', 'denmark'
};
europe_labels = { ...
    'Austria', 'Czechoslovakia', 'Poland', 'Gdańsk', 'Switzerland', ...
    'Soviet Union', 'Baltic States', 'Memel Territory', ...
    'Hungary', 'Yugoslavia', 'Romania', 'Italy', 'Other S and SE Europe', ...
    'France', 'Belgium', 'Netherlands', 'Luxembourg', 'Great Britain', 'Denmark'
};

% Totals over all states
europe_sums = sum(state_1939{:, europe_cols}, 1, 'omitnan');

% Sort (descending, reversed y-axis puts the largest bar on top)
[sorted_sums, idx] = sort(europe_sums, 'descend');
sorted_labels = europe_labels(idx);

% Chart
fig = figure();

b = barh(sorted_sums);

yticks(1:length(sorted_labels));
yticklabels(sorted_labels);

set(gca, 'YDir', 'reverse');
set(gca, 'XGrid', 'on');

xlabel('Number of migrants');
title('Migration from European countries');

% Value labels next to the bars
label_x = b.YEndPoints + 0.005 * max(xticks); % Small shift to the right
label_y = b.XEndPoints;

value_labels = string(sorted_sums);

text(label_x, label_y, value_labels, 'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'middle', 'FontSize', 8);

fontsize(fig, myfontsize, "points")


%% MAP: MIGRATION FROM CZECHOSLOVAKIA

col = 'czechoslovakia';

% Share of the 1950 population in %
base = population_1939_ipums(:, {'Shape', col});
base{:, col} = base{:, col} ./ population_1939_ipums.total_population .* 100;

% Class edges
values = base{:, col};
edges = quantile(values, linspace(0, 1, 6));

% Separate edges for binning, open at both ends (keeps -Inf/Inf out of the labels)
bin_edges = edges;
bin_edges(1) = -Inf;
bin_edges(end) = Inf;

% Assign each county to a class 1-5
base.color_class = discretize(values, bin_edges);

% Figure
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'color_class');
geobasemap(gx, 'none');
gx.Grid = 'off';
gx.Visible = 'off';

% Colors
colormap(gx, my_step_colormap);

% Color limits at x.5, so that classes 1-5 fall in the middle of each color
clim(gx, [0.5, 5.5]);

% Colorbar
cb = colorbar;

% 6 ticks placed exactly on the class boundaries
cb.Ticks = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5];

% Label the ticks with all 6 real edges (min to max), not the -Inf/Inf ones
cb.TickLabels = string(round(edges, 2));

% Title and formatting
t = title('Migration from Czechoslovakia');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");


%% MAP: MIGRATION FROM POLAND

col = 'poland';

% Share of the 1950 population in %
base = population_1939_ipums(:, {'Shape', col});
base{:, col} = base{:, col} ./ population_1939_ipums.total_population .* 100;

% Class edges
values = base{:, col};
edges = quantile(values, linspace(0, 1, 6));

% Separate edges for binning, open at both ends (keeps -Inf/Inf out of the labels)
bin_edges = edges;
bin_edges(1) = -Inf;
bin_edges(end) = Inf;

% Assign each county to a class 1-5
base.color_class = discretize(values, bin_edges);

% Figure
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'color_class');
geobasemap(gx, 'none');
gx.Grid = 'off';
gx.Visible = 'off';

% Colors
colormap(gx, my_step_colormap);

% Color limits at x.5, so that classes 1-5 fall in the middle of each color
clim(gx, [0.5, 5.5]);

% Colorbar
cb = colorbar;

% 6 ticks placed exactly on the class boundaries
cb.Ticks = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5];

% Label the ticks with all 6 real edges (min to max), not the -Inf/Inf ones
cb.TickLabels = string(round(edges, 2));

% Title and formatting
t = title('Migration from Poland');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");


%% BAR CHART: MIGRATION FROM NON-EUROPEAN COUNTRIES

% Non-European columns and their chart labels (same order)
world_cols = { ...
    'china_and_japan', 'rest_of_asia', 'usa', 'canada', 'brazil', ...
    'argentina', 'rest_of_america', 'south_african_union', ...
    'rest_of_africa', 'australia', 'oceania' ...
};
world_labels = { ...
    'China and Japan', 'Other Asia', 'USA', 'Canada', 'Brazil', ...
    'Argentina', 'Other America', 'South African Union', ...
    'Other Africa', 'Australia', 'Oceania' ...
};

% Totals over all states
world_sums = sum(state_1939{:, world_cols}, 1, 'omitnan');

% Sort (ascending, so the largest bar is on top)
[sorted_sums, idx] = sort(world_sums);
sorted_labels = world_labels(idx);

% Chart
fig = figure();

b = barh(sorted_sums);

yticks(1:length(sorted_labels));
yticklabels(sorted_labels);

set(gca, 'XGrid', 'on');

xlabel('Number of migrants');
title('Migration from non-European countries');

% Value labels next to the bars
label_x = b.YEndPoints + 0.005 * max(xticks); % Small shift to the right
label_y = b.XEndPoints;

value_labels = string(sorted_sums);

text(label_x, label_y, value_labels, 'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'middle', 'FontSize', 8);

fontsize(fig, myfontsize, "points")


%% MAP: MIGRATION FROM ABROAD

col = 'abroad';

% Share of the 1950 population in %
base = population_1939_ipums(:, {'Shape', col});
base{:, col} = base{:, col} ./ population_1939_ipums.total_population .* 100;

% Class edges
values = base{:, col};
edges = quantile(values, linspace(0, 1, 6));

% Separate edges for binning, open at both ends (keeps -Inf/Inf out of the labels)
bin_edges = edges;
bin_edges(1) = -Inf;
bin_edges(end) = Inf;

% Assign each county to a class 1-5
base.color_class = discretize(values, bin_edges);

% Figure
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'color_class');
geobasemap(gx, 'none');
gx.Grid = 'off';
gx.Visible = 'off';

% Colors
colormap(gx, my_step_colormap);

% Color limits at x.5, so that classes 1-5 fall in the middle of each color
clim(gx, [0.5, 5.5]);

% Colorbar
cb = colorbar;

% 6 ticks placed exactly on the class boundaries
cb.Ticks = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5];

% Label the ticks with all 6 real edges (min to max), not the -Inf/Inf ones
cb.TickLabels = string(round(edges, 2));

% Title and formatting
t = title('Migration from abroad');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");


%% MAP: ALL EXPELLEES IN WEST GERMANY

col = 'total_expellees';

% Share of the 1950 population in %
base = expellee_population_ipums(:, {'Shape', col});
base{:, col} = base{:, col} ./ expellee_population_ipums.total_population .* 100;

% Class edges
values = base{:, col};
edges = quantile(values, linspace(0, 1, 6));

% Separate edges for binning, open at both ends (keeps -Inf/Inf out of the labels)
bin_edges = edges;
bin_edges(1) = -Inf;
bin_edges(end) = Inf;

% Assign each county to a class 1-5
base.color_class = discretize(values, bin_edges);

% Figure
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'color_class');
geobasemap(gx, 'none');
gx.Grid = 'off';
gx.Visible = 'off';

% Colors
colormap(gx, my_step_colormap);

% Color limits at x.5, so that classes 1-5 fall in the middle of each color
clim(gx, [0.5, 5.5]);

% Colorbar
cb = colorbar;

% 6 ticks placed exactly on the class boundaries
cb.Ticks = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5];

% Label the ticks with all 6 real edges (min to max), not the -Inf/Inf ones
cb.TickLabels = string(round(edges, 2));

% Title and formatting
t = title('Expellees in West Germany');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");


%% MAP: SHARE OF DWELLINGS DAMAGED IN THE WAR

col = 'damaged_percentage';

% Already a share in %, no division needed
base = war_destruction_ipums(:, {'Shape', col});

% Class edges
values = base{:, col};
edges = quantile(values, linspace(0, 1, 6));

% Separate edges for binning, open at both ends (keeps -Inf/Inf out of the labels)
bin_edges = edges;
bin_edges(1) = -Inf;
bin_edges(end) = Inf;

% Assign each county to a class 1-5
base.color_class = discretize(values, bin_edges);

% Figure
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'color_class');
geobasemap(gx, 'none');
gx.Grid = 'off';
gx.Visible = 'off';

% Colors
colormap(gx, my_step_colormap);

% Color limits at x.5, so that classes 1-5 fall in the middle of each color
clim(gx, [0.5, 5.5]);

% Colorbar
cb = colorbar;

% 6 ticks placed exactly on the class boundaries
cb.Ticks = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5];

% Label the ticks with all 6 real edges (min to max), not the -Inf/Inf ones
cb.TickLabels = string(round(edges, 2));

% Title and formatting
t = title('Dwellings damaged in the war in West Germany');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");


%% SAVE FIGURES

if SAVE
    FolderName = ('chart_dump');
    FigList = findobj(allchild(0), 'flat', 'Type', 'figure');
    for iFig = 1:length(FigList)
      % Get the figure handle and its axes
      FigHandle = FigList(iFig);
      allAxes = findobj(FigHandle, 'Type', 'axes', '-or', 'Type', 'geoaxes');

      % Save as <figure number>.png
      FigName = num2str(get(FigHandle, 'Number'));
      saveas(FigHandle, fullfile(FolderName,strcat(FigName,'.png')));
    end
end
