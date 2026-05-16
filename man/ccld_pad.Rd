\name{ccld_pad}
\alias{ccld_pad}
\title{Pad facility license numbers to the API's canonical 9-digit form}
\usage{ccld_pad(facnums)}
\arguments{\item{facnums}{Character or numeric vector of license numbers.}}
\value{Character vector of 9-digit zero-padded license numbers.}
\description{The CCLD Transparency API requires every facility number to be left-padded with leading zeros to exactly 9 digits.}
