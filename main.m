% Zajęcia projektowe z Wizualizacji Danych
% Grupa 3, wtorek 17:15 - 20:00
% Borys Piątek 331725

SAVE = true; % Czy zapisać wykresy po wyświetleniu wszystkich


%% WCZYTANIE DANYCH DLA LANDÓW

migracje_base = readtable('migracje-1950.csv', 'VariableNamingRule', 'preserve');
migracje_base.Properties.RowNames = migracje_base{:,2};

migracje_sumy = readtable('suma-migracje-1950.csv');

zniszczenia = readtable('suma-zniszczen-domow-1950.csv');
zniszczenia.PercentageDestroyed = str2double(...
    replace(string(zniszczenia.PercentageDestroyed), ',', '.'));

%% WCZYTANIE DANYCH DLA GMIN

plik = 'źródła\tab7vz1950population-by-place-of-residence-on-september-1-1939.xlsx';

wybrane_kolumny = {'County ID', 'County Name', 'in the same State', ...
'in another state of the Federal Republic', 'in Berlin', ...
'in another state of the Soviet Occupation Zone', ...
'in the German eastern territories under foreign administration and in the Saar region', ...
'Silesia', 'Brandenburg', 'Pommerania', 'East Prussia', 'Saar region', ...
'abroad', 'Austria', 'Czechoslovakia', 'Poland', 'Gdansk'};

% Podanie paraewmtrów w detectImportOptions przed wybraniem kolumn
opts = detectImportOptions(plik, 'Sheet', 2, ...
    'VariableNamesRange', 'A3', ...
    'DataRange', 'A7', ...
    'VariableNamingRule', 'preserve');

% Wybranie kolumn
opts.SelectedVariableNames = wybrane_kolumny;

% Pobranie pliku zgodnie z opcjami
migracje_tab7_residence_1939 = readtable(plik, opts);

% Pobranie kształtów z IPUMS
niemcy_ipums = readgeotable('germany_ipums\niemcy_1949_1989\Germany_1950_v.1.0.shp');

% Pobranie tabelki z ID dla spisu i dla IPUMS
T_srodek = readtable('bridge.xlsx');
T_srodek = T_srodek(:, {'spis_ID', 'ipums_ID'});

% Łączenie spisu z mostem
T_temp = innerjoin(migracje_tab7_residence_1939, T_srodek, 'LeftKeys', 'County ID', 'RightKeys', 'spis_ID');

% Łączenie poprzedniego wyniku z IPUMS
migracje_ipums_final = innerjoin(T_temp, niemcy_ipums, 'LeftKeys', 'ipums_ID', 'RightKeys', 'KREIS_KENN');

% Przesunięcie "Shape" na początek (dla readgeotable)
migracje_ipums_final = movevars(migracje_ipums_final, 'Shape', 'Before', 1);

% Dodanie całej populacji migracyjnej
wybrane_kolumny = {'County ID', 'Total population 13/9/1950', ...
    'Total number of expellees 13/09/1950'};

plik = 'źródła\tab6vz1950population-expellees.xlsx';

opts = detectImportOptions(plik, 'Sheet', 2, ...
    'VariableNamesRange', 'A2', ...
    'DataRange', 'A4', ...
    'VariableNamingRule', 'preserve');

opts.SelectedVariableNames = wybrane_kolumny;

migracje_tab6_pop_expellees_1950 = readtable(plik, opts);

migracje_ipums_final = innerjoin(migracje_ipums_final, migracje_tab6_pop_expellees_1950, ...
    'LeftKeys', 'County ID', 'RightKeys', 'County ID');

% Dodanie znisczeń domów
wybrane_kolumny = {'County ID', ...
    'Share of normal dwellings affected by war damages'};

plik = 'źródła\tab16gz1950war-destructions.xlsx';

opts = detectImportOptions(plik, 'Sheet', 2, ...
    'VariableNamesRange', 'A2', ...
    'DataRange', 'A4', ...
    'VariableNamingRule', 'preserve');

opts.SelectedVariableNames = wybrane_kolumny;

migracje_tab16_war_destruction_1950 = readtable(plik, opts);

migracje_ipums_final = innerjoin(migracje_ipums_final, migracje_tab16_war_destruction_1950, ...
    'LeftKeys', 'County ID', 'RightKeys', 'County ID');


%% ZMIENNE GLOBALNE

% Kolory
g = gray(256); 
mygray = g(1:240, :);
my_step_colormap = [
    247, 247, 247;
    204, 204, 204;
    150, 150, 150;
     99,  99,  99;
     37,  37,  37
] / 255;

% Rozmiar czcionki
myfontsize = 15;


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
