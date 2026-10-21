function [fig, edges] = plot_quintile_map(geo_tab, col, chart_title, step_colormap, font_size, options)
%PLOT_QUINTILE_MAP Draw a choropleth map with one color class per quantile.
    arguments
        geo_tab table
        col (1,:) char
        chart_title (1,:) char
        step_colormap (:,3) double
        font_size (1,1) double
        options.UpperLabel (1,1) double = NaN
    end

    n_classes = size(step_colormap, 1);

    % Class edges
    values = geo_tab{:, col};
    edges = quantile(values, linspace(0, 1, n_classes + 1));

    % Separate edges for binning, open at both ends (keeps -Inf/Inf out of the labels)
    bin_edges = edges;
    bin_edges(1) = -Inf;
    bin_edges(end) = Inf;

    % Assign each shape to a class 1..n_classes
    geo_tab.color_class = discretize(values, bin_edges);

    % Map without a basemap, grid or axes
    fig = figure();
    gx = geoaxes;
    geoplot(gx, geo_tab, 'ColorVariable', 'color_class');
    geobasemap(gx, 'none');
    gx.Grid = 'off';
    gx.Visible = 'off';

    % One color per class
    colormap(gx, step_colormap);

    % Color limits at x.5, so that classes 1..n fall in the middle of each color
    clim(gx, [0.5, n_classes + 0.5]);

    % Colorbar ticks placed exactly on the class boundaries
    cb = colorbar(gx);
    cb.Ticks = 0.5:1:(n_classes + 0.5);

    % Label the ticks with the real edges
    label_edges = edges;
    if ~isnan(options.UpperLabel)
        label_edges(end) = options.UpperLabel;
    end
    cb.TickLabels = string(round(label_edges, 2));

    % Title (must be turned on again, as hidden axes also hide their title)
    t = title(gx, chart_title);
    t.Visible = 'on';

    fontsize(fig, font_size, "points");
end
