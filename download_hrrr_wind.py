"""
Download HRRR wind data (10m U and V components) for TS-SatFire wildfire locations.
 
For each fire event in the CSV files, downloads the HRRR analysis (fxx=0) 10 m wind
for every day of the fire's duration, cropped to a region around the fire location.
 
Notes:
  * HRRR GRIB winds are GRID-RELATIVE (aligned with the model's Lambert Conformal
    grid, not with north/east). The saved u10/v10 are therefore grid-relative.
    Wind speed is unaffected by this, but wind DIRECTION must be computed after
    rotating the components to earth-relative, so no direction is saved here.
  * If the 12Z run is missing from the archive for a date, neighbouring hours are
    tried (see --hours). Dates with no data at all are listed in missing_dates.csv.
 
Usage:
    python download_hrrr_wind.py --years 2017 --test --output ./hrrr_wind
    python download_hrrr_wind.py --years 2017 2018 2019 2020 2021 --output ./hrrr_wind
 
Requirements:
    pip install herbie-data netcdf4 pandas numpy xarray
"""
 
import argparse
import csv
import os
from datetime import timedelta
from pathlib import Path
 
import numpy as np
import pandas as pd
 
 
def check_netcdf_backend():
    """Fail early (before downloading anything) if xarray cannot write NetCDF files."""
    for module in ('netCDF4', 'h5netcdf', 'scipy'):
        try:
            __import__(module)
            return module
        except ImportError:
            continue
    raise ImportError(
        "No NetCDF writer found. Install one first, for example:\n"
        "    pip install netcdf4"
    )
 
 
def load_fire_events(years, roi_dir='./roi'):
    """Load fire event CSVs and return a DataFrame with Id, lat, lon, start_date, end_date."""
    dfs = []
    for year in years:
        filepath = os.path.join(roi_dir, f'us_fire_{year}_out_new.csv')
        if not os.path.exists(filepath):
            print(f"Warning: {filepath} not found, skipping year {year}")
            continue
        df = pd.read_csv(filepath)
        df['year'] = year
        dfs.append(df)
        print(f"Loaded {len(df)} fire events from {year}")
 
    if not dfs:
        raise FileNotFoundError("No CSV files found. Check roi_dir path.")
 
    combined = pd.concat(dfs, ignore_index=True)
    combined['Id'] = combined['Id'].astype(str)
 
    # Parse dates — handle both date-only and datetime formats
    combined['start_date'] = pd.to_datetime(combined['start_date'], errors='coerce')
    combined['end_date'] = pd.to_datetime(combined['end_date'], errors='coerce')
 
    print(f"\nTotal fire events loaded: {len(combined)}")
    return combined
 
 
def get_fire_dates(start_date, end_date):
    """Return list of dates between start and end inclusive."""
    dates = []
    current = start_date.date() if hasattr(start_date, 'date') else start_date
    end = end_date.date() if hasattr(end_date, 'date') else end_date
    while current <= end:
        dates.append(current)
        current += timedelta(days=1)
    return dates
 
 
def fetch_wind(date, hour, lat_min, lat_max, lon_min, lon_max):
    """
    Read HRRR 10 m U/V wind (analysis, fxx=0) for one date/hour and crop it.
    Raises an exception if the file is missing from the archive or cannot be read.
    Returns an xarray.Dataset with grid-relative u10, v10 and wind_speed.
    """
    from herbie import Herbie
 
    H = Herbie(
        f"{date} {hour:02d}:00",
        model='hrrr',
        product='sfc',
        fxx=0,
        verbose=False,
    )
    ds_u = H.xarray(":UGRD:10 m above ground:")
    ds_v = H.xarray(":VGRD:10 m above ground:")
 
    # HRRR longitudes are stored as 0-360
    def crop(ds):
        return ds.where(
            (ds.latitude >= lat_min) & (ds.latitude <= lat_max) &
            (ds.longitude >= lon_min % 360) & (ds.longitude <= lon_max % 360),
            drop=True,
        )
 
    ds_u = crop(ds_u)
    ds_v = crop(ds_v)
 
    u = ds_u['u10'] if 'u10' in ds_u else ds_u[list(ds_u.data_vars)[0]]
    v = ds_v['v10'] if 'v10' in ds_v else ds_v[list(ds_v.data_vars)[0]]
 
    if u.size == 0:
        raise ValueError("Cropped region is empty (fire outside the HRRR domain?)")
 
    ds_out = ds_u.copy()
    ds_out['u10'] = u            # grid-relative
    ds_out['v10'] = v            # grid-relative
    ds_out['wind_speed'] = np.sqrt(u ** 2 + v ** 2)   # rotation-invariant
    return ds_out
 
 
def download_hrrr_wind_for_fire(fire_id, lat, lon, dates, output_dir,
                                bbox_deg=1.5, hours=(12, 11, 13)):
    """
    Download HRRR 10 m wind for a fire location and date range.
 
    Returns (downloaded, skipped, missing_records) where missing_records is a list of
    (fire_id, date, last_error) for dates where no hour in `hours` could be read.
    """
    fire_output_dir = Path(output_dir) / fire_id
    fire_output_dir.mkdir(parents=True, exist_ok=True)
 
    lat_min, lat_max = lat - bbox_deg, lat + bbox_deg
    lon_min, lon_max = lon - bbox_deg, lon + bbox_deg
 
    downloaded = 0
    skipped = 0
    missing = []
 
    for date in dates:
        output_file = fire_output_dir / f"{date}_wind.nc"
 
        if output_file.exists():
            skipped += 1
            continue
 
        ds_out = None
        used_hour = None
        last_error = ''
        for hour in hours:
            try:
                ds_out = fetch_wind(date, hour, lat_min, lat_max, lon_min, lon_max)
                used_hour = hour
                break
            except Exception as e:
                # Missing/unreadable archive file for this hour: try the next one
                last_error = f"{type(e).__name__}: {str(e).strip().splitlines()[0] if str(e).strip() else ''}"
 
        if ds_out is None:
            print(f"    No HRRR data for {date} (tried hours {list(hours)}Z) -> {last_error}")
            missing.append((fire_id, str(date), last_error))
            continue
 
        ds_out.attrs['fire_id'] = fire_id
        ds_out.attrs['fire_lat'] = float(lat)
        ds_out.attrs['fire_lon'] = float(lon)
        ds_out.attrs['date'] = str(date)
        ds_out.attrs['source'] = f'HRRR analysis fxx=0, {used_hour:02d}Z run'
        ds_out.attrs['wind_note'] = ('u10/v10 are grid-relative (HRRR Lambert Conformal grid); '
                                     'rotate to earth-relative before computing wind direction')
 
        # Write to a temp file first so an interrupted write never leaves a corrupt
        # file that the skip-if-exists check would treat as complete.
        # Write errors are NOT caught here on purpose: they should stop the run.
        tmp_file = fire_output_dir / f"{date}_wind.nc.tmp"
        ds_out.to_netcdf(tmp_file)
        tmp_file.replace(output_file)
        downloaded += 1
 
    return downloaded, skipped, missing
 
 
def main():
    parser = argparse.ArgumentParser(description='Download HRRR wind data for TS-SatFire fire events')
    parser.add_argument('--years', nargs='+', type=int, default=[2017, 2018, 2019, 2020, 2021],
                        help='Years to download data for (default: 2017-2021)')
    parser.add_argument('--output', type=str, default='./hrrr_wind',
                        help='Output directory for downloaded data (default: ./hrrr_wind)')
    parser.add_argument('--roi_dir', type=str, default='./roi',
                        help='Directory containing the fire event CSV files (default: ./roi)')
    parser.add_argument('--bbox_deg', type=float, default=1.5,
                        help='Bounding box half-width in degrees around each fire (default: 1.5)')
    parser.add_argument('--hours', nargs='+', type=int, default=[12, 11, 13],
                        help='HRRR run hours (UTC) to try in order, per date (default: 12 11 13)')
    parser.add_argument('--test', action='store_true',
                        help='Test mode: only download first 3 fire events')
    args = parser.parse_args()
 
    print("=== HRRR Wind Data Downloader for TS-SatFire ===\n")
    backend = check_netcdf_backend()
    print(f"NetCDF backend: {backend}")
    print(f"Years: {args.years}")
    print(f"Output directory: {args.output}")
    print(f"Bounding box: ±{args.bbox_deg}° around each fire center")
    print(f"Run hours tried (UTC): {args.hours}")
    if args.test:
        print("TEST MODE: Only downloading first 3 fire events\n")
 
    fires = load_fire_events(args.years, roi_dir=args.roi_dir)
    fires = fires.dropna(subset=['lat', 'lon', 'start_date', 'end_date'])
    print(f"Fire events with complete data: {len(fires)}")
 
    if args.test:
        fires = fires.head(3)
 
    Path(args.output).mkdir(parents=True, exist_ok=True)
 
    total_downloaded = 0
    total_skipped = 0
    all_missing = []
 
    for n, (_, row) in enumerate(fires.iterrows(), start=1):
        fire_id = row['Id']
        lat = row['lat']
        lon = row['lon']
        dates = get_fire_dates(row['start_date'], row['end_date'])
        print(f"\n[{n}/{len(fires)}] Fire {fire_id}: {lat:.3f}°N, {lon:.3f}°E | "
              f"{row['start_date'].date()} → {row['end_date'].date()} ({len(dates)} days)")
 
        downloaded, skipped, missing = download_hrrr_wind_for_fire(
            fire_id=fire_id, lat=lat, lon=lon, dates=dates,
            output_dir=args.output, bbox_deg=args.bbox_deg, hours=tuple(args.hours),
        )
        total_downloaded += downloaded
        total_skipped += skipped
        all_missing.extend(missing)
        print(f"  Downloaded: {downloaded}, Skipped (already exist): {skipped}, "
              f"No data: {len(missing)}")
 
    # Save the list of dates that could not be downloaded
    missing_path = Path(args.output) / 'missing_dates.csv'
    with open(missing_path, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['fire_id', 'date', 'last_error'])
        writer.writerows(all_missing)
 
    print("\n=== Summary ===")
    print(f"Total downloaded: {total_downloaded}")
    print(f"Total skipped:    {total_skipped}")
    print(f"Total no data:    {len(all_missing)}  (listed in {missing_path})")
    print(f"Data saved to:    {args.output}")
 
 
if __name__ == '__main__':
    main()