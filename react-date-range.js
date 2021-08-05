import React, { useState } from 'react';
import { DateRangePicker, createStaticRanges } from 'react-date-range';
import {
	addDays,
	subDays,
	endOfDay,
	startOfDay,
	startOfMonth,
	endOfMonth,
	addMonths,
	startOfWeek,
	endOfWeek,
	startOfYear,
	endOfYear,
	addYears
} from 'date-fns';
import { Grid, Typography } from '@material-ui/core';
import './style.css';
import { Info, Receipt } from '@material-ui/icons';
import CardInfo from '../common/cardInfo';
import RegisteredChart from './charts/registeredChart';

const defineds = {
	startOfWeek: startOfWeek(new Date()),
	endOfWeek: endOfWeek(new Date()),
	startOfLastWeek: startOfWeek(addDays(new Date(), -7)),
	endOfLastWeek: endOfWeek(addDays(new Date(), -7)),
	startOfToday: startOfDay(new Date()),
	startOfLastSevenDay: startOfDay(addDays(new Date(), -7)),
	startOfLastThirtyDay: startOfDay(addDays(new Date(), -30)),
	startOfLastNintyDay: startOfDay(addDays(new Date(), -90)),
	endOfToday: endOfDay(new Date()),
	startOfYesterday: startOfDay(addDays(new Date(), -1)),
	endOfYesterday: endOfDay(addDays(new Date(), -1)),
	startOfMonth: startOfMonth(new Date()),
	endOfMonth: endOfMonth(new Date()),
	startOfLastMonth: startOfMonth(addMonths(new Date(), -1)),
	endOfLastMonth: endOfMonth(addMonths(new Date(), -1)),
	startOfYear: startOfYear(new Date()),
	endOfYear: endOfYear(new Date()),
	startOflastYear: startOfYear(addYears(new Date(), -1)),
	endOflastYear: endOfYear(addYears(new Date(), -1))
};

const sideBarOptions = () => {
	const customDateObjects = [
		{
			label: 'Lifetime',
			range: () => ({
				startDate: defineds.startOfToday,
				endDate: defineds.endOfToday
			})
		},
		{
			label: 'Today',
			range: () => ({
				startDate: defineds.startOfToday,
				endDate: defineds.endOfToday
			})
		},
		{
			label: 'Last 7 Days',
			range: () => ({
				startDate: defineds.startOfLastSevenDay,
				endDate: defineds.endOfToday
			})
		},
		{
			label: 'Last 30 Days',
			range: () => ({
				startDate: defineds.startOfLastThirtyDay,
				endDate: defineds.endOfToday
			})
		},
		{
			label: 'Last 90 Days',
			range: () => ({
				startDate: defineds.startOfLastNintyDay,
				endDate: defineds.endOfToday
			})
		},
		{
			label: 'This Week',
			range: () => ({
				startDate: defineds.startOfWeek,
				endDate: defineds.endOfWeek
			})
		},
		{
			label: 'Last Week',
			range: () => ({
				startDate: defineds.startOfLastWeek,
				endDate: defineds.endOfLastWeek
			})
		},
		{
			label: 'This Month',
			range: () => ({
				startDate: defineds.startOfMonth,
				endDate: defineds.endOfMonth
			})
		},
		{
			label: 'Last Month',
			range: () => ({
				startDate: defineds.startOfLastMonth,
				endDate: defineds.endOfLastMonth
			})
		},
		{
			label: 'This Year',
			range: () => ({
				startDate: defineds.startOfYear,
				endDate: defineds.endOfYear
			})
		},
		{
			label: 'Last Year',
			range: () => ({
				startDate: defineds.startOflastYear,
				endDate: defineds.endOflastYear
			})
		}
	];

	return customDateObjects;
};

const ChartSection = ({ classes, handleClick, data, user }) => {
	const [ state, setState ] = useState([
		{
			startDate: subDays(new Date(), 90),
			endDate: new Date(),
			key: 'selection'
		}
	]);
	const sideBar = sideBarOptions();

	const staticRanges = [
		// ...defaultStaticRanges,
		...createStaticRanges(sideBar)
	];
	return (
		<Grid container direction="column">
			<Grid item>
				<Typography color="primary" variant="h5" className={classes.sectionTitle}>
					Charts
				</Typography>
			</Grid>
			<Grid item className={classes.container}>
				<Grid container direction="column">
					<Grid style={{ padding: 8 }}>
						<DateRangePicker
							onChange={(item) => {
								console.log('item', item);
								setState([ item.selection ]);
							}}
							showSelectionPreview={true}
							moveRangeOnFirstSelection={false}
							months={2}
							ranges={state}
							direction="horizontal"
							staticRanges={staticRanges}
						/>
					</Grid>
				</Grid>
			</Grid>
		</Grid>
	);
};
export default ChartSection;