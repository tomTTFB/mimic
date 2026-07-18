# mimic element reference

_Generated from the source annotations by `tools/gen_reference.py` — do not edit by hand._

Every element is a constructor called with a single table of arguments, e.g. `m.LED{parent=root, label="STATUS", ...}`. Fields marked **required** must be present.

## Common fields

Almost every element accepts these; they are omitted from the per-element tables below.

| field | type | description |
|---|---|---|
| `parent` | `graphics_element` | the container to build into (required for children) |
| `x` / `y` | `integer` | position; auto-placed if omitted |
| `gframe` | `graphics_frame` | x/y/width/height as one frame, instead of separately |
| `fg_bg` | `cpair` | foreground/background colors; inherited from the parent if omitted |
| `hidden` | `boolean` | true to start hidden |
| `id` | `string` | optional element id |


## mimic helpers

Higher-level pieces unique to mimic. Prefer these over raw elements.

### BarChart

Vertical bars for comparing categories, with labels underneath.

| field | type | required | description |
|---|---|---|---|
| `bars` | `bar_entry[]` | yes | the bars |
| `max` | `number` |  | value at full height, defaults to 1.0 |
| `color` | `color` |  | default bar color, defaults to green |
| `bg` | `color` |  | empty color, defaults to the indicator background |
| `gap` | `integer` |  | blank columns between bars, defaults to 1 |
| `show_labels` | `boolean` |  | label row underneath, true by default |
| `ps` | `psil` |  | data source; inherited from the parent if omitted |
| `width` | `integer` | yes |  |
| `height` | `integer` | yes | total height, label row included |

### Dialog

A modal confirm/alert box, centered over the display.

| field | type | required | description |
|---|---|---|---|
| `message` | `string` | yes | body text |
| `title` | `string` |  | title bar text |
| `accent` | `color` |  | border and title color, defaults to gray |
| `width` | `integer` |  | defaults to 32 |
| `buttons` | `dialog_button[]` | yes | one or more buttons along the bottom |

### Gauge

A labelled bar: label, fill, and percentage on one line.

| field | type | required | description |
|---|---|---|---|
| `label` | `string` | yes | text to the left of the bar |
| `label_width` | `integer` |  | label column width, defaults to the label's length + 1 |
| `bind` | `string` |  | psil key |
| `transform` | `function` |  | value transform, applied before max= scaling |
| `max` | `number` |  | scale values by this instead of expecting a 0-1 fraction |
| `value` | `number` |  | initial value |
| `color` | `cpair` |  | bar fill/empty colors, defaults to green on the indicator background |
| `text_color` | `cpair` |  | colors for the trailing percentage, inherited from the parent if omitted |
| `show_percent` | `boolean` |  | draw the percentage after the bar, true by default |
| `ps` | `psil` |  |  |
| `width` | `integer` | yes | total width, label included |

### Grid

A grid of equal cells, for repeating one widget N times without computing.

| field | type | required | description |
|---|---|---|---|
| `ps` | `psil` |  | data source for the cells; inherited from the parent otherwise |
| `cols` | `integer` | yes | columns |
| `rows` | `integer` | yes | rows |
| `gap_x` | `integer` |  | blank columns between cells, defaults to 1 |
| `gap_y` | `integer` |  | blank rows between cells, defaults to 1 |
| `width` | `integer` |  | total width, defaults to the parent's |
| `height` | `integer` | yes | total height |
| `fg_bg` | `cpair` |  |  |

### LEDList

A column of labelled indicator lights from a table, which is the dominant.

| field | type | required | description |
|---|---|---|---|
| `leds` | `led_entry[]` | yes | the rows |
| `ps` | `psil` |  | data source for bound rows; inherited from parent if omitted |
| `kind` | `string` |  | default element for rows: "LED" or "IndicatorLight" |
| `color` | `cpair` |  | default on/off colors for rows |
| `width` | `integer` |  | defaults to the parent's width |
| `fg_bg` | `cpair` |  |  |

### Paginator

Pages through a list of items, N per page, with prev/next nav.

| field | type | required | description |
|---|---|---|---|
| `items` | `table[]` | yes | the data items to page through |
| `render` | `function` | yes | render(slot, item, index) - fill a slot Div for one item |
| `per_page` | `integer` | yes | slots per page |
| `cols` | `integer` |  | grid columns per page, defaults to 1 (a vertical stack) |
| `gap_x` | `integer` |  | column gap, defaults to 1 |
| `gap_y` | `integer` |  | row gap, defaults to 0 |
| `nav` | `boolean` |  | draw the prev / indicator / next row, true by default |
| `accent` | `color` |  | nav accent color, defaults to gray |
| `ps` | `psil` |  | data source for the pages |
| `width` | `integer` |  | defaults to the parent's width |
| `height` | `integer` | yes | total height, nav row included |

### Panel

A titled, bordered box.

| field | type | required | description |
|---|---|---|---|
| `title` | `string` |  | title text; omit for a bordered box with no title bar |
| `accent` | `color` |  | border and title bar color, defaults to gray |
| `title_fg` | `color` |  | title text color, defaults to black |
| `align` | `ALIGN` |  | title alignment, centered by default |
| `ps` | `psil` |  | data source for this subtree |
| `width` | `integer` |  |  |
| `height` | `integer` |  | total height, title bar included |
| `fg_bg` | `cpair` |  | content colors, defaults to the theme root |

### Row

Lays out cells left to right, so you stop hand-computing column x positions.

| field | type | required | description |
|---|---|---|---|
| `ps` | `psil` |  | data source for the cells; inherited from the parent otherwise |
| `count` | `integer` |  | number of equal-width cells (use this or widths=) |
| `widths` | `integer[]` |  | explicit cell widths; a 0 shares the leftover equally |
| `gap` | `integer` |  | blank columns between cells, defaults to 1 |
| `width` | `integer` |  | total width, defaults to the parent's |
| `height` | `integer` | yes | cell height |
| `fg_bg` | `cpair` |  |  |

### Table

Columns with a header and a scrolling body.

| field | type | required | description |
|---|---|---|---|
| `columns` | `table_column[]` | yes | the columns |
| `ps` | `psil` |  |  |
| `gap` | `integer` |  | blank columns between columns, defaults to 1 |
| `header_fg_bg` | `cpair` |  | header colors, defaults to the theme header |
| `row_fg_bg` | `cpair` |  | row colors, inherited from the parent otherwise |
| `max_rows` | `integer` |  | hard row ceiling, defaults to 500 |
| `width` | `integer` |  | defaults to the parent's width |
| `height` | `integer` | yes | total height, header included |

### Tabs

A tab bar over a stack of pages, which is how the cc-mek-scada front panels do.

| field | type | required | description |
|---|---|---|---|
| `tabs` | `tab_entry[]` | yes | the tabs, in page order |
| `ps` | `psil` |  | data source for every page |
| `min_width` | `integer` |  | per-tab width |
| `callback` | `function` |  | called with the page index when the tab changes |
| `width` | `integer` |  |  |
| `fg_bg` | `cpair` |  | tab bar colors |
| `page_height` | `integer` |  | page height, defaults to the rest of the parent |

### Trend

A value plotted over time.

| field | type | required | description |
|---|---|---|---|
| `width` | `integer` | yes | samples shown; one column per sample |
| `height` | `integer` | yes | chart height in characters (3x vertical resolution) |
| `style` | `string` |  | "area" (default) or "line" |
| `max` | `number` |  | value at full height, defaults to 1.0 |
| `min` | `number` |  | value at the baseline, defaults to 0 |
| `bind` | `string` |  | psil key; each publish pushes a sample |
| `transform` | `function` |  | value transform applied before scaling |
| `color` | `color` |  | plot color, defaults to green |
| `bg` | `color` |  | empty color, defaults to the indicator background |
| `fill` | `number` |  | initial value for every column, defaults to min |


## Elements (vendored from cc-mek-scada)

### Containers

#### AppMultiPane

_App Page Multi-Pane Display Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `panes` | `table` | yes | panes to swap between |
| `nav_colors` | `cpair` | yes | on/off colors (a/b respectively) for page navigator |
| `scroll_nav` | `boolean?` | yes | true to allow scrolling to change the active pane |
| `drag_nav` | `boolean?` | yes | true to allow mouse dragging to change the active pane (on mouse up) |
| `callback` | `function?` | yes | function to call when pane is changed by mouse interaction |
| `width` | `integer` |  | parent width if omitted |
| `height` | `integer` |  | parent height if omitted |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### ColorMap

_Color Map Graphics Element_

_Only common fields (see top)._

#### Div

_Div (Division, like in HTML) Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `width` | `integer` |  | parent width if omitted |
| `height` | `integer` |  | parent height if omitted |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### ListBox

_Scroll-able List Box Display Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `scroll_height` | `integer` | yes | height of internal scrolling container (must fit all elements vertically tiled) |
| `item_pad` | `integer` |  | spacing (lines) between items in the list (default 0) |
| `nav_fg_bg` | `cpair` |  | foreground/background colors for scroll arrows and bar area |
| `nav_active` | `cpair` |  | active colors for bar held down or arrow held down |
| `width` | `integer` |  | parent width if omitted |
| `height` | `integer` |  | parent height if omitted |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### MultiPane

_Multi-Pane Display Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `panes` | `table` | yes | panes to swap between |
| `width` | `integer` |  | parent width if omitted |
| `height` | `integer` |  | parent height if omitted |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### PipeNetwork

_Pipe Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `pipes` | `table` | yes | pipe list |
| `bg` | `color` |  | background color |

#### Rectangle

_Rectangle Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `border` | `graphics_border` |  |  |
| `thin` | `boolean` |  | true to use extra thin even borders |
| `even_inner` | `boolean` |  | true to make the inner area of a border even |
| `width` | `integer` |  | parent width if omitted |
| `height` | `integer` |  | parent height if omitted |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### TextBox

_Text Box Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `text` | `string` | yes | text to show |
| `alignment` | `ALIGN` |  | text alignment, left by default |
| `trim_whitespace` | `boolean` |  | true to trim whitespace before/after lines of text |
| `anchor` | `boolean` |  | true to use this as an anchor, making it focusable |
| `width` | `integer` |  | parent width if omitted |
| `height` | `integer` |  | minimum necessary height for wrapped text if omitted |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### Tiling

_"Basketweave" Tiling Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `fill_c` | `cpair` | yes | colors to fill with |
| `even` | `boolean` |  | whether to account for rectangular pixels |
| `border_c` | `color` |  | optional frame color |
| `width` | `integer` |  | parent width if omitted |
| `height` | `integer` |  | parent height if omitted |
| `fg_bg` | `cpair` |  | foreground/background colors |

### Indicators

#### AlarmLight

_Tri-State Alarm Indicator Light Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `label` | `string` | yes | indicator label |
| `c1` | `color` | yes | color for off state |
| `c2` | `color` | yes | color for alarm state |
| `c3` | `color` | yes | color for ring-back state |
| `min_label_width` | `integer` |  | label length if omitted |
| `flash` | `boolean` |  | whether to flash on alarm state rather than stay on |
| `period` | `PERIOD` |  | flash period |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### DataIndicator

_Data Indicator Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `label` | `string` | yes | indicator label |
| `unit` | `string` |  | indicator unit |
| `format` | `string` | yes | data format (lua string format) |
| `commas` | `boolean` |  | whether to use commas if a number is given (default to false) |
| `lu_colors` | `cpair` |  | label foreground color (a), unit foreground color (b) |
| `value` | `any` | yes | default value |
| `width` | `integer` | yes | length |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### HorizontalBar

_Horizontal Bar Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `show_percent` | `boolean` |  | whether or not to show the percent |
| `bar_fg_bg` | `cpair` |  | bar foreground/background colors if showing percent |
| `width` | `integer` |  | parent width if omitted |
| `height` | `integer` |  | parent height if omitted |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### IconIndicator

_Icon Indicator Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `label` | `string` | yes | indicator label |
| `states` | `table` | yes | state color and symbol table |
| `value` | `integer|boolean` |  | default state, defaults to 1 (true = 2, false = 1) |
| `min_label_width` | `integer` |  | label length if omitted |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### IndicatorLight

_Indicator Light Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `label` | `string` | yes | indicator label |
| `colors` | `cpair` | yes | on/off colors (a/b respectively) |
| `min_label_width` | `integer` |  | label length if omitted |
| `flash` | `boolean` |  | whether to flash on true rather than stay on |
| `period` | `PERIOD` |  | flash period |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### LED

_Indicator "LED" Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `label` | `string` | yes | indicator label |
| `colors` | `cpair` | yes | on/off colors (a/b respectively) |
| `min_label_width` | `integer` |  | label length if omitted |
| `flash` | `boolean` |  | whether to flash on true rather than stay on |
| `period` | `PERIOD` |  | flash period |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### LEDPair

_Indicator LED Pair Graphics Element (two LEDs provide: off, color_a, color_b)_

| field | type | required | description |
|---|---|---|---|
| `label` | `string` | yes | indicator label |
| `off` | `color` | yes | color for off |
| `c1` | `color` | yes | color for #1 on |
| `c2` | `color` | yes | color for #2 on |
| `min_label_width` | `integer` |  | label length if omitted |
| `flash` | `boolean` |  | whether to flash when on rather than stay on |
| `period` | `PERIOD` |  | flash period |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### PowerIndicator

_Power Indicator Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `label` | `string` | yes | indicator label |
| `unit` | `string` | yes | energy unit |
| `format` | `string` | yes | power format override (lua string format) |
| `rate` | `boolean?` | yes | whether to append /t to the end (power per tick) |
| `lu_colors` | `cpair` |  | label foreground color (a), unit foreground color (b) |
| `value` | `number` | yes | default value |
| `width` | `integer` | yes | length |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### RGBLED

_Indicator RGB LED Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `label` | `string` | yes | indicator label |
| `colors` | `table` | yes | colors to use |
| `min_label_width` | `integer` |  | label length if omitted |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### SignalBar

_Signal Bars Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `compact` | `boolean` |  | true to use a single character (works better against edges that extend out colors) |
| `colors_low_med` | `cpair` |  | color a for low signal quality, color b for medium signal quality |
| `disconnect_color` | `color` |  | color for the 'x' on disconnect |
| `fg_bg` | `cpair` |  | foreground/background colors (foreground is used for high signal quality) |

#### StateIndicator

_State (Text) Indicator Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `states` | `table` | yes | state color and text table |
| `value` | `integer` |  | default state, defaults to 1 |
| `min_width` | `integer` |  | max state text length if omitted |
| `height` | `integer` |  | 1 if omitted, must be an odd number |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### TriIndicatorLight

_Tri-State Indicator Light Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `label` | `string` | yes | indicator label |
| `c1` | `color` | yes | color for state 1 |
| `c2` | `color` | yes | color for state 2 |
| `c3` | `color` | yes | color for state 3 |
| `min_label_width` | `integer` |  | label length if omitted |
| `flash` | `boolean` |  | whether to flash on state 2 or 3 rather than stay on |
| `period` | `PERIOD` |  | flash period |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### VerticalBar

_Vertical Bar Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `width` | `integer` |  | parent width if omitted |
| `height` | `integer` |  | parent height if omitted |
| `fg_bg` | `cpair` |  | foreground/background colors |

### Controls

#### App

_App Button Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `text` | `string` | yes | app icon text |
| `title` | `string` | yes | app title text |
| `callback` | `function` | yes | function to call on touch |
| `app_fg_bg` | `cpair` | yes | app icon foreground/background colors |
| `active_fg_bg` | `cpair` |  | foreground/background colors when pressed |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### Checkbox

_Checkbox Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `label` | `string` | yes | checkbox text |
| `box_fg_bg` | `cpair` | yes | colors for checkbox |
| `disable_fg_bg` | `cpair` |  | text colors when disabled |
| `default` | `boolean` |  | default value |
| `callback` | `function` |  | function to call on press |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### HazardButton

_Hazard-bordered Button Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `text` | `string` | yes | text to show on button |
| `accent` | `color` | yes | accent color for hazard border |
| `dis_colors` | `cpair` |  | text color and border color when disabled |
| `callback` | `function` | yes | function to call on touch |
| `timeout` | `integer` |  | override for the default 1.5 second timeout, in seconds |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### MultiButton

_Multi Button Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `options` | `table` | yes | button options |
| `callback` | `function` | yes | function to call on touch |
| `default` | `integer` |  | default state, defaults to options[1] |
| `min_width` | `integer` |  | text length + 2 if omitted |
| `height` | `integer` |  | parent height if omitted |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### NumericSpinbox

_Spinbox Numeric Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `default` | `number` |  | default value, defaults to 0.0 |
| `min` | `number` |  | default 0, currently must be 0 or greater |
| `max` | `number` |  | default max number that can be displayed with the digits configuration |
| `whole_num_precision` | `integer` | yes | number of whole number digits |
| `fractional_precision` | `integer` | yes | number of fractional digits |
| `arrow_fg_bg` | `cpair` | yes | arrow foreground/background colors |
| `arrow_disable` | `color` |  | color when disabled (default light gray) |
| `callback` | `function` |  | function to call on touch |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### PushButton

_Button Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `text` | `string` | yes | button text |
| `callback` | `function` | yes | function to call on touch |
| `min_width` | `integer` |  | text length if omitted |
| `alignment` | `ALIGN` |  | text align if min width > length |
| `active_fg_bg` | `cpair` |  | foreground/background colors when pressed |
| `dis_fg_bg` | `cpair` |  | foreground/background colors when disabled |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### Radio2D

_2D Radio Button Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `rows` | `integer` | yes |  |
| `columns` | `integer` | yes |  |
| `options` | `table` | yes |  |
| `radio_colors` | `cpair` | yes | radio button colors (inner & outer) |
| `select_color` | `color` |  | color for radio button when selected |
| `color_map` | `table` |  | colors for each radio button when selected |
| `disable_color` | `color` |  | color for radio button when disabled |
| `disable_fg_bg` | `cpair` |  | text colors when disabled |
| `default` | `integer` |  | default state, defaults to options[1] |
| `callback` | `function` |  | function to call on touch |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### RadioButton

_Radio Button Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `options` | `table` | yes | button options |
| `radio_colors` | `cpair` | yes | radio button colors (inner & outer) |
| `select_color` | `color` | yes | color for radio button border when selected |
| `dis_fg_bg` | `cpair` |  | foreground/background colors when disabled |
| `default` | `integer` |  | default state, defaults to options[1] |
| `min_width` | `integer` |  | text length + 2 if omitted |
| `callback` | `function` |  | function to call on touch |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### Sidebar

_Sidebar Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `height` | `integer` |  | parent height if omitted |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### SwitchButton

_Button Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `text` | `string` | yes | button text |
| `active_text` | `string` |  | button text when active (optional if active_fg_bg set) |
| `callback` | `function` | yes | function to call on touch |
| `default` | `boolean` |  | default state, defaults to off (false) |
| `min_width` | `integer` |  | text length + 2 if omitted |
| `active_fg_bg` | `cpair` |  | foreground/background colors when pressed (optional if active_text set) |
| `dis_fg_bg` | `cpair` |  | foreground/background colors when disabled |
| `height` | `integer` |  | parent height if omitted |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### TabBar

_Tab Bar Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `tabs` | `table` | yes | tab options |
| `callback` | `function` | yes | function to call on tab change |
| `min_width` | `integer` |  | text length + 2 if omitted |
| `width` | `integer` |  | parent width if omitted |
| `fg_bg` | `cpair` |  | foreground/background colors |

### Forms

#### NumberField

_Numeric Value Entry Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `default` | `number` |  | default value, defaults to 0 |
| `min` | `number` |  | minimum, enforced on unfocus |
| `max` | `number` |  | maximum, enforced on unfocus |
| `max_chars` | `integer` |  | maximum number of characters, defaults to width |
| `max_int_digits` | `integer` |  | maximum number of integer digits, enforced on unfocus |
| `max_frac_digits` | `integer` |  | maximum number of fractional digits, enforced on unfocus |
| `allow_decimal` | `boolean` |  | true to allow decimals |
| `allow_negative` | `boolean` |  | true to allow negative numbers |
| `align_right` | `boolean` |  | true to align right while unfocused |
| `dis_fg_bg` | `cpair` |  | foreground/background colors when disabled |
| `on_unfocus` | `function` |  | callback when the field becomes unfocused |
| `width` | `integer` |  | parent width if omitted |
| `fg_bg` | `cpair` |  | foreground/background colors |

#### TextField

_Text Value Entry Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `value` | `string` |  | initial value |
| `max_len` | `integer` |  | maximum string length |
| `censor` | `string` |  | character to replace text with when printing to screen |
| `dis_fg_bg` | `cpair` |  | foreground/background colors when disabled |
| `on_unfocus` | `function` |  | callback when the field becomes unfocused |
| `width` | `integer` |  | parent width if omitted |
| `fg_bg` | `cpair` |  | foreground/background colors |

### Animations

#### Waiting

_Loading/Waiting Animation Graphics Element_

| field | type | required | description |
|---|---|---|---|
| `fg_bg` | `cpair` |  | foreground/background colors |
