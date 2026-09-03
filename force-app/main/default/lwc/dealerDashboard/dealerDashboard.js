import { LightningElement, track, wire } from 'lwc';
import getDashboardMetrics from '@salesforce/apex/DealerDashboardController.getDashboardMetrics';
import { loadScript } from 'lightning/platformResourceLoader';
import chartjs from '@salesforce/resourceUrl/chartjs';

const doughnutColors = [
    '#032f33', // Very dark green
    '#0d6b69', // Rotex primary green
    '#1f8a88', // Medium teal
    '#3ebab8', // Light teal
    '#76d7d5', // Very light teal
    '#a7e6e5', // Pale mint
    '#d2f5f4'  // Lightest mint
];

export default class DealerDashboard extends LightningElement {
    @track invoiceQty = '0';
    @track approvedCustomers = '0';
    @track openLeads = '0';
    @track pendingQuotes = '0';
    @track lowStockProducts = '0';
    @track targetAchievement = 0;
    @track topCount = 5;

    @track fiscalYearOptions = [];
    @track quarterOptions = [
        { label: 'All Quarters', value: '' },
        { label: 'Q1 (Apr - Jun)', value: 'Q1' },
        { label: 'Q2 (Jul - Sep)', value: 'Q2' },
        { label: 'Q3 (Oct - Dec)', value: 'Q3' },
        { label: 'Q4 (Jan - Mar)', value: 'Q4' }
    ];
    @track monthOptions = [
        { label: 'All Months', value: '' },
        { label: 'April', value: '4' },
        { label: 'May', value: '5' },
        { label: 'June', value: '6' },
        { label: 'July', value: '7' },
        { label: 'August', value: '8' },
        { label: 'September', value: '9' },
        { label: 'October', value: '10' },
        { label: 'November', value: '11' },
        { label: 'December', value: '12' },
        { label: 'January', value: '1' },
        { label: 'February', value: '2' },
        { label: 'March', value: '3' }
    ];
    @track selectedYear = '';
    @track selectedQuarter = '';
    @track selectedMonth = '';
    @track salesTrendTitle = 'Quarterly Sales Trend (Target vs Actual)';

    chart;
    abChart;
    quoteChart;
    leadChart;
    inventoryChart;
    isChartJsInitialized = false;
    @track metricsData = {};

    connectedCallback() {
        let options = [{ label: 'All Years', value: '' }];
        for (let y = 2000; y <= 3000; y++) {
            options.push({ label: y.toString(), value: y.toString() });
        }
        this.fiscalYearOptions = options;
    }

    @wire(getDashboardMetrics, { yearStr: '$selectedYear', quarter: '$selectedQuarter', month: '$selectedMonth' })
    wiredMetrics({ error, data }) {
        if (data) {
            this.metricsData = data;
            this.invoiceQty = this.formatNumber(data.invoiceQty);
            this.approvedCustomers = this.formatNumber(data.approvedCustomers);
            this.openLeads = this.formatNumber(data.openLeads);
            this.pendingQuotes = this.formatNumber(data.pendingQuotes);
            this.lowStockProducts = this.formatNumber(data.lowStockProducts);
            this.targetAchievement = data.targetAchievement || 0;

            if (this.isChartJsInitialized) {
                this.renderChart();
            }
        } else if (error) {
            console.error('Error fetching dashboard metrics', error);
        }
    }

    handleYearChange(event) {
        this.selectedYear = event.detail.value;
        this.updateSalesTrendTitle();
    }

    handleQuarterChange(event) {
        this.selectedQuarter = event.detail.value;
        if (this.selectedQuarter) {
            this.selectedMonth = ''; // Reset month if quarter is selected
        }
        this.updateSalesTrendTitle();
    }

    handleMonthChange(event) {
        this.selectedMonth = event.detail.value;
        if (this.selectedMonth) {
            this.selectedQuarter = ''; // Reset quarter if month is selected
        }
        this.updateSalesTrendTitle();
    }
    handleClear(event) {
        this.selectedYear = '';
        this.selectedQuarter = '';
        this.selectedMonth = '';
        this.updateSalesTrendTitle();
    }
    updateSalesTrendTitle() {
        if (this.selectedMonth) {
            this.salesTrendTitle = 'Monthly Sales Trend (Target vs Actual)';
        } else if (this.selectedQuarter) {
            this.salesTrendTitle = 'Quarterly Sales Trend (Target vs Actual)';
        } else {
            this.salesTrendTitle = 'Quarterly Sales Trend (Target vs Actual)';
        }
    }

    renderedCallback() {
        if (this.isChartJsInitialized) {
            return;
        }

        loadScript(this, chartjs)
            .then(() => {
                this.isChartJsInitialized = true;
                if (this.metricsData) {
                    this.renderChart();
                }
            })
            .catch(error => {
                console.error('Error loading ChartJS', error);
            });
    }

    mapToCustomScale(val) {
        const steps = [0, 500000, 1000000, 2500000, 5000000, 10000000, 20000000, 30000000, 50000000, 70000000, 100000000, 150000000];
        if (!val || val <= 0) return 0;
        if (val >= steps[11]) return 11;
        
        for (let i = 0; i < 11; i++) {
            if (val >= steps[i] && val <= steps[i+1]) {
                return i + ((val - steps[i]) / (steps[i+1] - steps[i]));
            }
        }
        return 0;
    }

    renderChart() {
        if (this.chart) {
            this.chart.destroy();
        }

        const canvas = this.template.querySelector('canvas.salesChart');
        if (!canvas) return;

        const ctx = canvas.getContext('2d');
        
        const rawTargets = this.metricsData.chartTargets || [0, 0, 0, 0];
        const rawActuals = this.metricsData.chartActuals || [0, 0, 0, 0];
        
        const mappedTargets = rawTargets.map(v => this.mapToCustomScale(v));
        const mappedActuals = rawActuals.map(v => this.mapToCustomScale(v));

        this.chart = new window.Chart(ctx, {
            type: 'bar',
            data: {
                labels: this.metricsData.chartLabels || ['Q1', 'Q2', 'Q3', 'Q4'],
                datasets: [
                    {
                        label: 'Budget (Target)',
                        type: 'line',
                        data: mappedTargets,
                        borderColor: '#ff9800',
                        backgroundColor: '#ff9800',
                        borderWidth: 2,
                        pointBackgroundColor: '#fff',
                        pointBorderColor: '#ff9800',
                        pointBorderWidth: 2,
                        pointRadius: 4,
                        fill: false,
                        tension: 0.3
                    },
                    {
                        label: 'Actual',
                        type: 'bar',
                        data: mappedActuals,
                        backgroundColor: '#0d6b69', // Rotex green theme
                        borderRadius: 4,
                        barPercentage: 0.6,
                        categoryPercentage: 0.8
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'top',
                        align: 'end',
                        labels: {
                            usePointStyle: true,
                            boxWidth: 8
                        }
                    },
                    tooltip: {
                        callbacks: {
                            label: (context) => {
                                const isTarget = context.datasetIndex === 0;
                                const originalValue = isTarget ? rawTargets[context.dataIndex] : rawActuals[context.dataIndex];
                                return `${context.dataset.label}: ${this.formatNumber(originalValue)}`;
                            }
                        }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        min: 0,
                        max: 11,
                        ticks: {
                            stepSize: 1,
                            autoSkip: false,
                            callback: function (value) {
                                const labels = ['0', '5 Lakh', '10 Lakh', '25 Lakh', '50 Lakh', '1 Crore', '2 Crore', '3 Crore', '5 Crore', '7 Crore', '10 Crore', '15 Crore'];
                                return labels[Math.round(value)] || '';
                            }
                        },
                        grid: {
                            color: '#f0f0f0',
                            drawBorder: false
                        }
                    },
                    x: {
                        grid: {
                            display: false,
                            drawBorder: false
                        }
                    }
                }
            }
        });

        // --- Render Actual vs Budget Chart ---
        if (this.abChart) {
            this.abChart.destroy();
        }

        const abCanvas = this.template.querySelector('canvas.actualBudgetChart');
        if (!abCanvas) return;

        const abCtx = abCanvas.getContext('2d');

        this.abChart = new window.Chart(abCtx, {
            type: 'bar',
            data: {
                labels: ['Actual', 'Target'],
                datasets: [
                    {
                        label: 'Value',
                        data: [
                            this.metricsData.totalActualValue || 0,
                            this.metricsData.totalTargetValue || 0
                        ],
                        backgroundColor: [
                            '#0d6b69', // Rotex green for Actual
                            '#f59e0b'  // Orange for Budget
                        ],
                        borderRadius: 4,
                        barPercentage: 0.85,
                        categoryPercentage: 0.9
                    }
                ]
            },
            options: {
                indexAxis: 'y', // This makes it a horizontal bar chart
                layout: {
                    padding: { right: 80 } // Give space for the text
                },
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false // We don't need a legend since Y-axis has the labels
                    },
                    tooltip: {
                        callbacks: {
                            label: (context) => {
                                return `Value: ${this.formatNumber(context.raw)}`;
                            }
                        }
                    }
                },
                scales: {
                    x: {
                        display: false, // Completely hide x-axis
                        beginAtZero: true
                    },
                    y: {
                        grid: {
                            display: false,
                            drawBorder: false
                        }
                    }
                }
            },
            plugins: [{
                id: 'inlineBarValues',
                afterDatasetsDraw: (chart) => {
                    const ctx = chart.ctx;
                    chart.data.datasets.forEach((dataset, i) => {
                        const meta = chart.getDatasetMeta(i);
                        meta.data.forEach((bar, index) => {
                            const data = dataset.data[index];
                            if (data !== null && data !== undefined) {
                                ctx.fillStyle = '#032f33';
                                ctx.font = 'bold 13px sans-serif';
                                ctx.textAlign = 'left';
                                ctx.textBaseline = 'middle';
                                const formattedVal = this.formatNumber(data);
                                ctx.fillText(formattedVal, bar.x + 8, bar.y);
                            }
                        });
                    });
                }
            }]
        });

        const centerTextPlugin = {
            id: 'centerText',
            beforeDraw: function (chart) {
                if (chart.config.options.plugins.centerText) {
                    const ctx = chart.ctx;
                    const centerConfig = chart.config.options.plugins.centerText;

                    const centerX = (chart.chartArea.left + chart.chartArea.right) / 2;
                    const centerY = (chart.chartArea.top + chart.chartArea.bottom) / 2;

                    const innerRadius = chart.innerRadius || 50;
                    const valFontSize = Math.max(16, innerRadius / 2);
                    const labelFontSize = Math.max(10, innerRadius / 3.5);

                    ctx.save();

                    ctx.font = "bold " + valFontSize + "px sans-serif";
                    ctx.fillStyle = "#032f33";
                    ctx.textAlign = "center";
                    ctx.textBaseline = "middle";
                    ctx.fillText(centerConfig.value, centerX, centerY - (valFontSize / 4));

                    ctx.font = labelFontSize + "px sans-serif";
                    ctx.fillStyle = "#64748b";
                    ctx.fillText(centerConfig.label, centerX, centerY + (valFontSize / 1.5));

                    ctx.restore();
                }
            }
        };

        // --- Render Quote By Status Chart ---
        if (this.quoteChart) {
            this.quoteChart.destroy();
        }

        const quoteCanvas = this.template.querySelector('canvas.quoteStatusChart');
        if (quoteCanvas) {
            const quoteCtx = quoteCanvas.getContext('2d');

            this.quoteChart = new window.Chart(quoteCtx, {
                type: 'doughnut',
                data: {
                    labels: this.metricsData.quoteStatusLabels || [],
                    datasets: [{
                        data: this.metricsData.quoteStatusCounts || [],
                        backgroundColor: doughnutColors,
                        borderWidth: 2,
                        borderColor: '#ffffff'
                    }]
                },
                options: {
                    layout: {
                        padding: { left: 0, right: 30, top: 15, bottom: 15 }
                    },
                    responsive: true,
                    maintainAspectRatio: false,
                    cutout: '55%', // Reduced to make the circle thicker
                    plugins: {
                        legend: { display: false },
                        centerText: {
                            value: this.metricsData.totalQuotes,
                            label: 'Quotes'
                        }
                    }
                },
                plugins: [centerTextPlugin]
            });
        }

        // --- Render Leads By Status Chart ---
        if (this.leadChart) {
            this.leadChart.destroy();
        }

        const leadCanvas = this.template.querySelector('canvas.leadStatusChart');
        if (leadCanvas) {
            const leadCtx = leadCanvas.getContext('2d');
            this.leadChart = new window.Chart(leadCtx, {
                type: 'doughnut',
                data: {
                    labels: this.metricsData.leadStatusLabels || [],
                    datasets: [{
                        data: this.metricsData.leadStatusCounts || [],
                        backgroundColor: doughnutColors,
                        borderWidth: 2,
                        borderColor: '#ffffff'
                    }]
                },
                options: {
                    layout: {
                        padding: { left: 0, right: 30, top: 15, bottom: 15 }
                    },
                    responsive: true,
                    maintainAspectRatio: false,
                    cutout: '55%', // Reduced to make the circle thicker
                    plugins: {
                        legend: { display: false },
                        centerText: {
                            value: this.metricsData.totalLeads,
                            label: 'Leads'
                        }
                    }
                },
                plugins: [centerTextPlugin]
            });
        }

        // --- Render Inventory By Status Chart ---
        if (this.inventoryChart) {
            this.inventoryChart.destroy();
        }

        const invCanvas = this.template.querySelector('canvas.inventoryStatusChart');
        if (invCanvas) {
            const invCtx = invCanvas.getContext('2d');
            this.inventoryChart = new window.Chart(invCtx, {
                type: 'bar',
                data: {
                    labels: this.metricsData.inventoryStatusLabels || [],
                    datasets: [{
                        label: 'Inventory',
                        data: this.metricsData.inventoryStatusQuantities || [],
                        backgroundColor: doughnutColors,
                        borderRadius: 4,
                        barPercentage: 0.6,
                        categoryPercentage: 0.8
                    }]
                },
                options: {
                    layout: {
                        padding: { top: 25 }
                    },
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { display: false },
                        tooltip: {
                            callbacks: {
                                label: (context) => {
                                    const qty = context.raw || 0;
                                    const count = this.metricsData.inventoryStatusCounts ? (this.metricsData.inventoryStatusCounts[context.dataIndex] || 0) : 0;
                                    return `Qty: ${this.formatNumber(qty)} (Count: ${this.formatNumber(count)})`;
                                }
                            }
                        }
                    },
                    scales: {
                        x: {
                            grid: { display: false, drawBorder: false }
                        },
                        y: {
                            display: false,
                            beginAtZero: true
                        }
                    }
                },
                plugins: [{
                    id: 'inlineBarValuesTop',
                    afterDatasetsDraw: (chart) => {
                        const ctx = chart.ctx;
                        chart.data.datasets.forEach((dataset, i) => {
                            const meta = chart.getDatasetMeta(i);
                            meta.data.forEach((bar, index) => {
                                const data = dataset.data[index];
                                if (data !== null && data !== undefined) {
                                    ctx.fillStyle = '#032f33';
                                    ctx.font = 'bold 13px sans-serif';
                                    ctx.textAlign = 'center';
                                    ctx.textBaseline = 'bottom';
                                    const formattedVal = this.formatNumber(data);
                                    ctx.fillText(formattedVal, bar.x, bar.y - 6);
                                }
                            });
                        });
                    }
                }]
            });
        }

        // --- Render Top Orders Chart ---
        this.renderTopOrdersChart();
    }

    renderTopOrdersChart() {
        if (this.topOrdersChart) {
            this.topOrdersChart.destroy();
        }

        const topCanvas = this.template.querySelector('canvas.topOrdersChart');
        if (topCanvas && this.metricsData.topOrderLabels && this.metricsData.topOrderLabels.length > 0) {

            const topCtx = topCanvas.getContext('2d');

            // Limit the data shown based on the selected dropdown value
            const displayedLabels = this.metricsData.topOrderLabels.slice(0, this.topCount);
            const displayedValues = this.metricsData.topOrderValues.slice(0, this.topCount);

            // Adjust container height dynamically to keep bar thickness constant based on ACTUAL items
            const chartBody = topCanvas.parentElement;
            if (chartBody) {
                const actualCount = displayedLabels.length || 1;
                chartBody.style.height = `${actualCount * 45 + 30}px`;
            }

            this.topOrdersChart = new window.Chart(topCtx, {
                type: 'bar',
                data: {
                    labels: displayedLabels,
                    datasets: [{
                        label: 'Net Value',
                        data: displayedValues,
                        backgroundColor: '#2ea59c', // Green theme
                        borderRadius: 4,
                        barPercentage: 0.6,
                        categoryPercentage: 0.8,
                        maxBarThickness: 30
                    }]
                },
                options: {
                    indexAxis: 'y', // horizontal bar chart
                    layout: {
                        padding: { right: 80 } // Give space for inline text
                    },
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { display: false },
                        tooltip: {
                            callbacks: {
                                label: (context) => {
                                    return `${context.dataset.label}: ${this.formatNumber(context.raw)}`;
                                }
                            }
                        }
                    },
                    scales: {
                        x: {
                            display: false, // Completely hide x-axis
                            beginAtZero: true
                        },
                        y: {
                            grid: { display: false, drawBorder: false }
                        }
                    }
                },
                plugins: [{
                    id: 'inlineBarValuesTopOrders',
                    afterDatasetsDraw: (chart) => {
                        const ctx = chart.ctx;
                        chart.data.datasets.forEach((dataset, i) => {
                            const meta = chart.getDatasetMeta(i);
                            meta.data.forEach((bar, index) => {
                                const data = dataset.data[index];
                                if (data !== null && data !== undefined) {
                                    ctx.fillStyle = '#032f33';
                                    ctx.font = 'bold 13px sans-serif';
                                    ctx.textAlign = 'left';
                                    ctx.textBaseline = 'middle';
                                    const formattedVal = this.formatNumber(data);
                                    ctx.fillText(formattedVal, bar.x + 8, bar.y);
                                }
                            });
                        });
                    }
                }]
            });
        }
    }

    handleTopCountChange(event) {
        this.topCount = parseInt(event.target.value, 10);
        this.renderTopOrdersChart();
    }

    formatNumber(num) {
        if (num === null || num === undefined) return '0';
        return num.toLocaleString('en-IN');
    }

    get abChartAchievementStyle() {
        return `height: ${this.targetAchievement}%;`;
    }

    get quoteLegendItems() {
        if (!this.metricsData || !this.metricsData.quoteStatusLabels) return [];
        return this.metricsData.quoteStatusLabels.map((label, index) => {
            let line1 = label;
            let line2 = '';
            if (label === 'Submitted to Customer') {
                line1 = 'Submitted to';
                line2 = 'Customer';
            } else if (label === 'Submit for SOA Approval') {
                line1 = 'Submit for SOA';
                line2 = 'Approval';
            }
            const color = doughnutColors[index % doughnutColors.length];
            return {
                id: index,
                line1: line1,
                line2: line2,
                hasLine2: line2.length > 0,
                count: this.metricsData.quoteStatusCounts[index] || 0,
                colorStyle: `background-color: ${color}; width: 12px; height: 12px; border-radius: 50%; display: inline-block; flex-shrink: 0;`
            };
        });
    }

    get leadLegendItems() {
        if (!this.metricsData || !this.metricsData.leadStatusLabels) return [];
        return this.metricsData.leadStatusLabels.map((label, index) => {
            const color = doughnutColors[index % doughnutColors.length];
            return {
                id: index,
                line1: label,
                hasLine2: false,
                count: this.metricsData.leadStatusCounts[index] || 0,
                colorStyle: `background-color: ${color}; width: 12px; height: 12px; border-radius: 50%; display: inline-block; flex-shrink: 0;`
            };
        });
    }

    get targetAchievementStyle() {
        return `width: ${this.targetAchievement}%`;
    }
}