
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
    'Schleswig-Holstein', 'Bremen', 'Niedersachsen', 'Nordrhein-Westfalen', ...
    'Hessen', 'Rheinland-Pfalz', 'Baden-Württemberg', 'Bayern'};

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

%% Słupkowy dla stałej/imigranckiej populacji

% Pobranie kolumn
pop_rodzima = migracje_sumy.NativePopulation;
pop_imigrancka = migracje_sumy.ImmigrantPopulation;
landy = migracje_sumy.Land;

% Przygotowanie danych do wykresu
[posortowana_imigrancka, indeksy] = sort(pop_imigrancka, "descend");

posortowana_rodzima = pop_rodzima(indeksy);
posortowane_nazwy = landy(indeksy);

dane_do_wykresu = [posortowana_rodzima, posortowana_imigrancka];

% Wykres
fig = figure();

b = barh(posortowane_nazwy, dane_do_wykresu, 'grouped'); 

xlabel('Liczba ludności');
ylabel("Land")

legend({'Populacja rodzima', 'Populacja imigrancka'}, 'Location', 'northeast');

title('Populacja imigrancka kontra populacja rodzima (1950 r.)');

set(gca, 'XGrid', 'on');

xlim([0, 13500000]);
xticks(0:3000000:15000000)

% Etykiety serii 1. (populacja stała)
xtips = b(1).YEndPoints + 0.005 * max(xticks); % Drobne przesunięcie w prawo
ytips = b(1).XEndPoints;
labels = string(b(1).YData);
text(xtips, ytips, labels, 'HorizontalAlignment','left', ...
    'VerticalAlignment','middle','FontSize',8);

% Etykiety serii 2. (populacja imigrancka)
xtips = b(2).YEndPoints + 0.005 * max(xticks); % Drobne przesunięcie w prawo
ytips = b(2).XEndPoints;
labels = string(b(2).YData);
text(xtips, ytips, labels, 'HorizontalAlignment','left', ...
    'VerticalAlignment','middle','FontSize',8);

fontsize(fig, myfontsize, "points")


%% Migracje wewnętrzne w Niemczech Zachodnich

col = 'in another state of the Federal Republic';

% Przygotowanie danych bazowych i obliczenie wskaźnika
base = migracje_ipums_final(:, {'Shape', col});
    base{:, col} = base{:, col} ./ ...
    migracje_ipums_final{:, 'Total population 13/9/1950'} .* 100;

% Obliczenie schodków
dane = base{:, col};
prawdziwe_krawedzie = quantile(dane, linspace(0, 1, 6)); 

% Stworzenie osobnej zmiennej do kategoryzacji (żeby nie zepsuć etykiet napisem -Inf / Inf)
krawedzie_obliczeniowe = prawdziwe_krawedzie;
krawedzie_obliczeniowe(1) = -Inf; 
krawedzie_obliczeniowe(end) = Inf;

% Kategoryzacja danych
base.Kategoria_Koloru = discretize(dane, krawedzie_obliczeniowe);

% Inicjalizacja figury
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'Kategoria_Koloru');
geobasemap(gx, 'none'); 
gx.Grid = 'off'; 
gx.Visible = 'off'; 

% Kolory
colormap(gx, my_step_colormap);

% Ustawienie granic na x.5, żeby przesunąć krawędzie
clim(gx, [0, 5]); 

% Konfiguracja paska kolorów
cb = colorbar;

% Wymuszenie 6 znaczników dokładnie na granicach kolorów
cb.Ticks = [0, 1, 2, 3, 4, 5];

% Przekazanie WSZYSTKICH 6 prawdziwych krawędzi (od min do max)
% Używamy oryginalnych kwantyli, a nie tych z -Inf
cb.TickLabels = string(round(prawdziwe_krawedzie, 2)); 

% Tytuł i formatowanie
t = title('Migracje wewnętrzne');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");


%% Migracje z Niemiec Wschodnich na landach zachodnich

col = 'in another state of the Soviet Occupation Zone';

% Przygotowanie danych bazowych i obliczenie wskaźnika
base = migracje_ipums_final(:, {'Shape', col});
    base{:, col} = base{:, col} ./ ...
    migracje_ipums_final{:, 'Total population 13/9/1950'} .* 100;

% Obliczenie schodków
dane = base{:, col};
prawdziwe_krawedzie = quantile(dane, linspace(0, 1, 6)); 

% Stworzenie osobnej zmiennej do kategoryzacji (żeby nie zepsuć etykiet napisem -Inf / Inf)
krawedzie_obliczeniowe = prawdziwe_krawedzie;
krawedzie_obliczeniowe(1) = -Inf; 
krawedzie_obliczeniowe(end) = Inf;

% Kategoryzacja danych
base.Kategoria_Koloru = discretize(dane, krawedzie_obliczeniowe);

% Inicjalizacja figury
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'Kategoria_Koloru');
geobasemap(gx, 'none'); 
gx.Grid = 'off'; 
gx.Visible = 'off'; 

% Kolory
colormap(gx, my_step_colormap);

% Ustawienie granic na x.5, żeby przesunąć krawędzie
clim(gx, [0.5, 5.5]); 

% Konfiguracja paska kolorów
cb = colorbar;

% Wymuszenie 6 znaczników dokładnie na granicach kolorów
cb.Ticks = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5];

% Przekazanie WSZYSTKICH 6 prawdziwych krawędzi (od min do max)
% Używamy oryginalnych kwantyli, a nie tych z -Inf
cb.TickLabels = string(round(prawdziwe_krawedzie, 2)); 

% Tytuł i formatowanie
t = title('Migracje z Niemiec Wschodnich');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");


%% Migracje z Berlina na landach zachodnich

col = 'in Berlin';

% Przygotowanie danych bazowych i obliczenie wskaźnika
base = migracje_ipums_final(:, {'Shape', col});
    base{:, col} = base{:, col} ./ ...
    migracje_ipums_final{:, 'Total population 13/9/1950'} .* 100;

% Obliczenie schodków
dane = base{:, col};
prawdziwe_krawedzie = quantile(dane, linspace(0, 1, 6)); 

% Stworzenie osobnej zmiennej do kategoryzacji (żeby nie zepsuć etykiet napisem -Inf / Inf)
krawedzie_obliczeniowe = prawdziwe_krawedzie;
krawedzie_obliczeniowe(1) = -Inf; 
krawedzie_obliczeniowe(end) = Inf;

% Kategoryzacja danych
base.Kategoria_Koloru = discretize(dane, krawedzie_obliczeniowe);

% Inicjalizacja figury
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'Kategoria_Koloru');
geobasemap(gx, 'none'); 
gx.Grid = 'off'; 
gx.Visible = 'off'; 

% Kolory
colormap(gx, my_step_colormap);

% Ustawienie granic na x.5, żeby przesunąć krawędzie
clim(gx, [0.5, 5.5]); 

% Konfiguracja paska kolorów
cb = colorbar;

% Wymuszenie 6 znaczników dokładnie na granicach kolorów
cb.Ticks = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5];

% Przekazanie WSZYSTKICH 6 prawdziwych krawędzi (od min do max)
% Używamy oryginalnych kwantyli, a nie tych z -Inf
cb.TickLabels = string(round(prawdziwe_krawedzie, 2)); 

% Tytuł i formatowanie
t = title('Migracje z Berlina');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");



%% Migracje z ziem wschodnich na landach zachodnich

col = 'in the German eastern territories under foreign administration and in the Saar region';

% Przygotowanie danych bazowych i obliczenie wskaźnika
base = migracje_ipums_final(:, {'Shape', col});
    base{:, col} = base{:, col} ./ ...
    migracje_ipums_final{:, 'Total population 13/9/1950'} .* 100;

% Obliczenie schodków
dane = base{:, col};
prawdziwe_krawedzie = quantile(dane, linspace(0, 1, 6)); 

% Stworzenie osobnej zmiennej do kategoryzacji (żeby nie zepsuć etykiet napisem -Inf / Inf)
krawedzie_obliczeniowe = prawdziwe_krawedzie;
krawedzie_obliczeniowe(1) = -Inf; 
krawedzie_obliczeniowe(end) = Inf;

% Kategoryzacja danych
base.Kategoria_Koloru = discretize(dane, krawedzie_obliczeniowe);

% Inicjalizacja figury
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'Kategoria_Koloru');
geobasemap(gx, 'none'); 
gx.Grid = 'off'; 
gx.Visible = 'off'; 

% Kolory
colormap(gx, my_step_colormap);

% Ustawienie granic na x.5, żeby przesunąć krawędzie
clim(gx, [0.5, 5.5]); 

% Konfiguracja paska kolorów
cb = colorbar;

% Wymuszenie 6 znaczników dokładnie na granicach kolorów
cb.Ticks = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5];

% Przekazanie WSZYSTKICH 6 prawdziwych krawędzi (od min do max)
% Używamy oryginalnych kwantyli, a nie tych z -Inf
prawdziwe_krawedzie(end) = 49.755630473378680;
cb.TickLabels = string(round(prawdziwe_krawedzie, 2)); 

% Tytuł i formatowanie
t = title('Migracje z ziem wschodnich oraz okręgu Saary');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");



%% Wykres słupkowy emigracji z Niemiec Wschodnich, Berlina i ziem wschodnich

% Kolumny z tabeli z danymi
landy_okupacja = {'Silesia', 'Brandenburg', 'Pommerania', 'East Prussia'};
% Polskie nazwy
landy_okupacja_polskie = {'Śląsk', 'Brandenburgia', 'Pomorze', 'Prusy Wschodnie'};

% Sumy dla grup
landy_okupajca_sumy = sum(migracje_base{:, landy_okupacja});
berlin_suma = sum(migracje_base.Berlin);
nrd_suma = sum(migracje_base.GDR_sum);

% Sortowanie sum
wyniki = [nrd_suma, berlin_suma, landy_okupajca_sumy];
[posortowane_wyniki, indeksy] = sort(wyniki);

% Polskie etykiety i posortowanie ich zgodnie z indeksami sum
etykiety_na_wykres = [{'Niemcy Wschodnie', 'Berlin'}, landy_okupacja_polskie];
posortowane_etykiety = etykiety_na_wykres(indeksy);

% Wykres
fig = figure();

b = barh(posortowane_wyniki);

yticks(1:length(posortowane_etykiety));
yticklabels(posortowane_etykiety);

set(gca, 'XGrid', 'on');

xlabel('Liczba emigrantów');
title('Emigracje z Niemiec Wschodnich, Berlina i ziem wschodnich');

wspolrzedne_X = b.YEndPoints + 0.005 * max(xticks); % Drobne przesunięcie w prawo
wspolrzedne_Y = b.XEndPoints;

etykiety = string(posortowane_wyniki);

text(wspolrzedne_X, wspolrzedne_Y, etykiety, 'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'middle', 'FontSize', 8);

fontsize(fig, myfontsize, "points")


%% Państwa z których pochodizli imigranci wspomniane z nazwy w zbiorze

mapa_swiata_gis = readgeotable('cshapes/CShapes-2.0.shp');
mapa_1937_gis = mapa_swiata_gis( ...
    mapa_swiata_gis.gwsyear <= 1937 & mapa_swiata_gis.gweyear >= 1937, :);

% Wszystkie nazwy w zbiorze
panstwa_pochodzenia = { ...
    'Austria', 'Czechoslovakia', 'Poland', 'Gdansk', ...
    'Switzerland', 'Soviet Union', 'Estonia', 'Latvia', ...
    'Lithuania', 'Hungary', 'Yugoslavia', 'Romania', ...
    'Italy', 'France', 'Belgium', 'Netherlands', ...
    'Luxembourg', 'Great Britain', 'Denmark', 'China', ...
    'Japan', 'USA', 'Canada', 'Brazil', ...
    'Argentina', 'South Africa', 'Australia', 'Germany' ...
};

% Niektóre nazwy w gisowksiej mapie się różnią
stare_nazwy = {'Gdansk', 'Soviet Union', 'Romania', 'Italy', ...
    'Great Britain', 'USA'};
nowe_nazwy = {'Danzig', 'Russia (Soviet Union)', 'Rumania', ...
    'Italy/Sardinia', 'United Kingdom', 'United States of America'};
panstwa_pochodzenia_zmapowane = replace(panstwa_pochodzenia, stare_nazwy, nowe_nazwy);

% Wybranie państwa (ich rekordy) zainteresowania ze wszystkich
indeksy_szukanych = ismember(mapa_1937_gis.cntry_name, panstwa_pochodzenia_zmapowane);
% Wykorzystanie indeksów do znalezienia gisowskich kształtów
kraje_zaznaczone_gis = mapa_1937_gis(indeksy_szukanych, :);

% Wykres
fig = figure();

geoplot(mapa_1937_gis, 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', [0.8 0.8 0.8]);
hold on;

geoplot(kraje_zaznaczone_gis, 'FaceColor', '#D95319', 'EdgeColor', 'black');

title('Wymienione państwa pochodzenia imigrantów na tle mapy świata z 1937 r.');

fontsize(fig, myfontsize, "points")


%% Imigracje z Europy

% Wybranie kolumn europejskich i suma
emigracje_eur = migracje_base(:, 29:47);
emigracje_eur_suma = sum(emigracje_eur); 

% Sortowanie
[posortowane_liczby, indeksy] = sort(emigracje_eur_suma{:, :}, 'descend');

etykiety_pl = { ...
    'Austria', 'Czechosłowacja', 'Polska', 'Gdańsk', 'Szwajcaria', ...
    'Związek Radziecki', 'Kraje Bałtyckie', 'Terytorium Kłajpedy', ...
    'Węgry', 'Jugosławia', 'Rumunia', 'Włochy', 'Pozostałe kraje S i SE Europy', ...
    'Francja', 'Belgia', 'Holandia', 'Luksemburg', 'Wielka Brytania', 'Dania'
};
posortowane_etykiety = etykiety_pl(indeksy);

% Wykres
fig = figure();

b = barh(posortowane_liczby);

yticks(1:length(posortowane_etykiety));
yticklabels(posortowane_etykiety);

set(gca, 'YDir', 'reverse');
set(gca, 'XGrid', 'on');

xlabel('Liczba emigrantów');
title('Emigracje z państw Europy');

wspolrzedne_X = b.YEndPoints + 0.005 * max(xticks); % Drobne przesunięcie w prawo
wspolrzedne_Y = b.XEndPoints;

etykiety = string(posortowane_liczby);

text(wspolrzedne_X, wspolrzedne_Y, etykiety, 'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'middle', 'FontSize', 8);

fontsize(fig, myfontsize, "points")


%% Migracje z Czechosłowacji

col = 'Czechoslovakia';

% Przygotowanie danych bazowych i obliczenie wskaźnika
base = migracje_ipums_final(:, {'Shape', col});
    base{:, col} = base{:, col} ./ ...
    migracje_ipums_final{:, 'Total population 13/9/1950'} .* 100;

% Obliczenie schodków
dane = base{:, col};
prawdziwe_krawedzie = quantile(dane, linspace(0, 1, 6)); 

% Stworzenie osobnej zmiennej do kategoryzacji (żeby nie zepsuć etykiet napisem -Inf / Inf)
krawedzie_obliczeniowe = prawdziwe_krawedzie;
krawedzie_obliczeniowe(1) = -Inf; 
krawedzie_obliczeniowe(end) = Inf;

% Kategoryzacja danych
base.Kategoria_Koloru = discretize(dane, krawedzie_obliczeniowe);

% Inicjalizacja figury
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'Kategoria_Koloru');
geobasemap(gx, 'none'); 
gx.Grid = 'off'; 
gx.Visible = 'off'; 

% Kolory
colormap(gx, my_step_colormap);

% Ustawienie granic na x.5, żeby przesunąć krawędzie
clim(gx, [0.5, 5.5]); 

% Konfiguracja paska kolorów
cb = colorbar;

% Wymuszenie 6 znaczników dokładnie na granicach kolorów
cb.Ticks = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5];

% Przekazanie WSZYSTKICH 6 prawdziwych krawędzi (od min do max)
% Używamy oryginalnych kwantyli, a nie tych z -Inf
prawdziwe_krawedzie(end) = 49.755630473378680;
cb.TickLabels = string(round(prawdziwe_krawedzie, 2)); 

% Tytuł i formatowanie
t = title('Migracje z Czechosłowacji');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");


%% Migracje z Polski

col = 'Poland';

% Przygotowanie danych bazowych i obliczenie wskaźnika
base = migracje_ipums_final(:, {'Shape', col});
    base{:, col} = base{:, col} ./ ...
    migracje_ipums_final{:, 'Total population 13/9/1950'} .* 100;

% Obliczenie schodków
dane = base{:, col};
prawdziwe_krawedzie = quantile(dane, linspace(0, 1, 6)); 

% Stworzenie osobnej zmiennej do kategoryzacji (żeby nie zepsuć etykiet napisem -Inf / Inf)
krawedzie_obliczeniowe = prawdziwe_krawedzie;
krawedzie_obliczeniowe(1) = -Inf; 
krawedzie_obliczeniowe(end) = Inf;

% Kategoryzacja danych
base.Kategoria_Koloru = discretize(dane, krawedzie_obliczeniowe);

% Inicjalizacja figury
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'Kategoria_Koloru');
geobasemap(gx, 'none'); 
gx.Grid = 'off'; 
gx.Visible = 'off'; 

% Kolory
colormap(gx, my_step_colormap);

% Ustawienie granic na x.5, żeby przesunąć krawędzie
clim(gx, [0.5, 5.5]); 

% Konfiguracja paska kolorów
cb = colorbar;

% Wymuszenie 6 znaczników dokładnie na granicach kolorów
cb.Ticks = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5];

% Przekazanie WSZYSTKICH 6 prawdziwych krawędzi (od min do max)
% Używamy oryginalnych kwantyli, a nie tych z -Inf
prawdziwe_krawedzie(end) = 49.755630473378680;
cb.TickLabels = string(round(prawdziwe_krawedzie, 2)); 

% Tytuł i formatowanie
t = title('Migracje z Polski');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");



%% Emigracja ze świata

% Wybranie państw świata i suma
emigracje_swiat = migracje_base(:, 51:61);
emigracje_swiat_suma = sum(emigracje_swiat);

% Sortowanie
[posortowane_liczby, indeksy] = sort(emigracje_swiat_suma{:, :});

etykiety_pl = { ...
    'Chiny i Japonia', 'Pozostałe kraje Azji', 'USA', 'Kanada', 'Brazylia', ...
    'Argentyna', 'Pozostałe kraje Ameryki', 'Związek Południowej Afryki', ...
    'Pozostałe kraje Afryki', 'Australia', 'Oceania' ...
};
posortowane_etykiety = etykiety_pl(indeksy);

% Wykres
fig = figure();

b = barh(posortowane_liczby);

yticks(1:length(posortowane_etykiety));
yticklabels(posortowane_etykiety);

set(gca, 'XGrid', 'on');

xlabel('Liczba emigrantów');
title('Emigracje z państw świata');

wspolrzedne_X = b.YEndPoints + 0.005 * max(xticks); % Drobne przesunięcie w prawo
wspolrzedne_Y = b.XEndPoints;

etykiety = string(posortowane_liczby);

text(wspolrzedne_X, wspolrzedne_Y, etykiety, 'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'middle', 'FontSize', 8);

fontsize(fig, myfontsize, "points")


%% Migracje zza granicy

col = 'abroad';

% Przygotowanie danych bazowych i obliczenie wskaźnika
base = migracje_ipums_final(:, {'Shape', col});
    base{:, col} = base{:, col} ./ ...
    migracje_ipums_final{:, 'Total population 13/9/1950'} .* 100;

% Obliczenie schodków
dane = base{:, col};
prawdziwe_krawedzie = quantile(dane, linspace(0, 1, 6)); 

% Stworzenie osobnej zmiennej do kategoryzacji (żeby nie zepsuć etykiet napisem -Inf / Inf)
krawedzie_obliczeniowe = prawdziwe_krawedzie;
krawedzie_obliczeniowe(1) = -Inf; 
krawedzie_obliczeniowe(end) = Inf;

% Kategoryzacja danych
base.Kategoria_Koloru = discretize(dane, krawedzie_obliczeniowe);

% Inicjalizacja figury
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'Kategoria_Koloru');
geobasemap(gx, 'none'); 
gx.Grid = 'off'; 
gx.Visible = 'off'; 

% Kolory
colormap(gx, my_step_colormap);

% Ustawienie granic na x.5, żeby przesunąć krawędzie
clim(gx, [0.5, 5.5]); 

% Konfiguracja paska kolorów
cb = colorbar;

% Wymuszenie 6 znaczników dokładnie na granicach kolorów
cb.Ticks = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5];

% Przekazanie WSZYSTKICH 6 prawdziwych krawędzi (od min do max)
% Używamy oryginalnych kwantyli, a nie tych z -Inf
prawdziwe_krawedzie(end) = 49.755630473378680;
cb.TickLabels = string(round(prawdziwe_krawedzie, 2)); 

% Tytuł i formatowanie
t = title('Migracje zza granicy');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");


%% Całkowite imigracje w Nieczech Zachodnich

col = 'Total number of expellees 13/09/1950';

% Przygotowanie danych bazowych i obliczenie wskaźnika
base = migracje_ipums_final(:, {'Shape', col});
    base{:, col} = base{:, col} ./ ...
    migracje_ipums_final{:, 'Total population 13/9/1950'} .* 100;

% Obliczenie schodków
dane = base{:, col};
prawdziwe_krawedzie = quantile(dane, linspace(0, 1, 6)); 

% Stworzenie osobnej zmiennej do kategoryzacji (żeby nie zepsuć etykiet napisem -Inf / Inf)
krawedzie_obliczeniowe = prawdziwe_krawedzie;
krawedzie_obliczeniowe(1) = -Inf; 
krawedzie_obliczeniowe(end) = Inf;

% Kategoryzacja danych
base.Kategoria_Koloru = discretize(dane, krawedzie_obliczeniowe);

% Inicjalizacja figury
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'Kategoria_Koloru');
geobasemap(gx, 'none'); 
gx.Grid = 'off'; 
gx.Visible = 'off'; 

% Kolory
colormap(gx, my_step_colormap);

% Ustawienie granic na x.5, żeby przesunąć krawędzie
clim(gx, [0.5, 5.5]); 

% Konfiguracja paska kolorów
cb = colorbar;

% Wymuszenie 6 znaczników dokładnie na granicach kolorów
cb.Ticks = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5];

% Przekazanie WSZYSTKICH 6 prawdziwych krawędzi (od min do max)
% Używamy oryginalnych kwantyli, a nie tych z -Inf
cb.TickLabels = string(round(prawdziwe_krawedzie, 2)); 

% Tytuł i formatowanie
t = title('Całkowite migracje do Niemiec Zachodnich');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");



%% Zniszczenia procentowe w Niemczech Zachodnich

col = 'Share of normal dwellings affected by war damages';

% Przygotowanie danych bazowych i obliczenie wskaźnika
base = migracje_ipums_final(:, {'Shape', col});

% Obliczenie schodków
dane = base{:, col};
prawdziwe_krawedzie = quantile(dane, linspace(0, 1, 6)); 

% Stworzenie osobnej zmiennej do kategoryzacji (żeby nie zepsuć etykiet napisem -Inf / Inf)
krawedzie_obliczeniowe = prawdziwe_krawedzie;
krawedzie_obliczeniowe(1) = -Inf; 
krawedzie_obliczeniowe(end) = Inf;

% Kategoryzacja danych
base.Kategoria_Koloru = discretize(dane, krawedzie_obliczeniowe);

% Inicjalizacja figury
fig = figure();
gx = geoaxes;
geoplot(base, 'ColorVariable', 'Kategoria_Koloru');
geobasemap(gx, 'none'); 
gx.Grid = 'off'; 
gx.Visible = 'off'; 

% Kolory
colormap(gx, my_step_colormap);

% Ustawienie granic na x.5, żeby przesunąć krawędzie
clim(gx, [0.5, 5.5]); 

% Konfiguracja paska kolorów
cb = colorbar;

% Wymuszenie 6 znaczników dokładnie na granicach kolorów
cb.Ticks = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5];

% Przekazanie WSZYSTKICH 6 prawdziwych krawędzi (od min do max)
% Używamy oryginalnych kwantyli, a nie tych z -Inf
cb.TickLabels = string(round(prawdziwe_krawedzie, 2)); 

% Tytuł i formatowanie
t = title('Zniszczenia procentowe domów w Niemczech Zachodnich');
t.Visible = 'on';
fontsize(fig, myfontsize, "points");


%% Zapis
if SAVE
    FolderName = ('chart_dump');  
    FigList = findobj(allchild(0), 'flat', 'Type', 'figure');
    for iFig = 1:length(FigList)
      % Pobranie uchwytu do wykresu i wzięcie jego osi
      FigHandle = FigList(iFig);
      allAxes = findobj(FigHandle, 'Type', 'axes', '-or', 'Type', 'geoaxes');

      % Ukrycie tytułów na czas zapisu
      for iAx = 1:length(allAxes)
          allAxes(iAx).Title.Visible = 'on';
      end

      % Zapis
      FigName = num2str(get(FigHandle, 'Number'));
      saveas(FigHandle, fullfile(FolderName,strcat(FigName,'.png')));

      % Ponowne pokazanie po zapisie
      for iAx = 1:length(allAxes)
          allAxes(iAx).Title.Visible = 'on';
      end
    end
end
