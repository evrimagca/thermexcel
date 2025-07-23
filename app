# appnew.py
import pandas as pd
import matplotlib.pyplot as plt
import io
import base64
from flask import Flask, request, render_template

app = Flask(__name__)

zone_definitions = {
    "1": (1, 50),
    "2": (51, 150),
    "3": (151, 300),
    "4": (301, 600),
    "5": (601, 1000),
    "6": (1001, 1400),
    "7": (1401, 1800),
    "8": (1801, float("inf")),
}

# Load cost data
cost_data = pd.read_csv("4modelsupdated.csv")
cost_data['Zone'] = pd.to_numeric(cost_data['Zone'], errors='coerce')
cost_data.dropna(subset=['Zone'], inplace=True)
cost_data['Zone'] = cost_data['Zone'].astype(int)

@app.route('/', methods=['GET', 'POST'])
def index():
    expected_costs = []
    error_msg = None

    if request.method == 'POST':
        cryoshipper = request.form['cryoshipper']
        shipments_per_month = int(request.form.get('shipments_per_month', 1))

        # Read zone weights from form and convert to probabilities
        zone_weights = {}
        for i in range(1, 9):
            zone_weights[i] = float(request.form.get(f'zone_{i}', 0)) / 100.0

        services = sorted(cost_data[cost_data['Cryoshipper'] == 'ThermExcel']['Service'].unique())

        for service in services:
            therm_zone_costs = []
            alt_zone_costs = []
            alt_available = True

            for zone, weight in zone_weights.items():
                therm_price = cost_data[
                    (cost_data['Cryoshipper'] == 'ThermExcel') &
                    (cost_data['Zone'] == zone) &
                    (cost_data['Service'] == service)
                ]['Price']

                alt_price = cost_data[
                    (cost_data['Cryoshipper'].str.strip() == cryoshipper.strip()) &
                    (cost_data['Zone'] == zone) &
                    (cost_data['Service'] == service)
                ]['Price']

                if not therm_price.empty:
                    therm_12mo = therm_price.values[0] * 2 * shipments_per_month * 12
                    therm_zone_costs.append(therm_12mo * weight)
                if not alt_price.empty:
                    alt_12mo = alt_price.values[0] * 2 * shipments_per_month * 12
                    alt_zone_costs.append(alt_12mo * weight)
                elif weight > 0:
                    alt_available = False  # Mark as missing only if zone weight is nonzero

            therm_expected = sum(therm_zone_costs)
            alt_expected = sum(alt_zone_costs) if alt_available else None
            savings = (alt_expected - therm_expected) if alt_available else "N/A"

            expected_costs.append({
                'Service': service,
                'ThermExcel (12 mo)': round(therm_expected, 2),
                'Alt Model (12 mo)': round(alt_expected, 2) if alt_expected is not None else "N/A",
                'Expected Savings': round(savings, 2) if isinstance(savings, float) else "N/A"
            })

    return render_template(
        'indexnew.html',
        expected_costs=expected_costs,
        error_msg=error_msg
    )

if __name__ == '__main__':
    app.run(debug=True)
