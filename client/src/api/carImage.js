/*
  carImage.js
  Returns the actual auction lot photo for a vehicle using its VIN.
  Images are hosted on the Nexteppe S3 bucket used by KO Towing Marietta.
  Falls back to an imagin.studio render if no VIN is available.
*/

const S3_BASE    = 'https://s3.amazonaws.com/vid2.nexteppe.com/media4/images/sourceimages/25506'
const IM_CUSTOMER = 'hrjavascript-mastery'
const IM_BASE     = 'https://cdn.imagin.studio/getimage'

export function fetchCarImage(make, model, year, vin) {
  // Real lot photo — build URL from VIN
  if (vin) {
    return Promise.resolve(`${S3_BASE}/${vin.trim()}_01.jpg`)
  }

  // Fallback: imagin.studio render by make/model/year
  if (!make || !model) return Promise.resolve(null)

  const params = new URLSearchParams({
    customer:    IM_CUSTOMER,
    make:        make.toLowerCase().trim(),
    modelFamily: model.toLowerCase().trim().replace(/\s+/g, '-'),
    zoomType:    'fullscreen'
  })
  if (year) params.set('modelYear', String(year))

  return Promise.resolve(IM_BASE + '?' + params)
}
