Fall 2012 MAP Results by Students with Target Setting and Comparative Distributions
========================================================
This file is the literate programming source for a script that pulls our data from our Data Analysis `MySQL` database. I'll add references to how we get data into the database, as needed.  Nevertheless, this document focuses on the process of how we pull data from the DB and analyse it in [`R`](www.r-project.org)

There are three aims of this document
  1. To show how I connect `R` to a `MySQL' database and use a `SQL` query to populate a dataframe with the data I want.
  2. Provide some exmaples of data manipulation and building graphics leveraging `ggplot2`.
  3. Emphasize how writing functions can save you so much time (both in producing analyses and in debugging code).
  4. Encourage [literate probramming](http://en.wikipedia.org/wiki/Literate_programming) practices (which are dead simple in [RStudio](http://www.rstudio.org)).
  5. Inspire the adoption of `R` throughout the KIPP Network. 


___

## Prelims

I start by setting some global parameters for my R markdown file (i.e, this file), then updating the present working directory and loading the packaged used in the data analysis.


```r
opts_chunk$set(tidy = TRUE, echo = TRUE, dpi = 150, fig.align = "center", fig.height = 6.3125, 
    fig.width = 5, fig.path = "./public_figures/", message = FALSE)
```




```r
setwd("~/Dropbox/Consulting/KIPP Ascend/Data Analysis/MAP/Code/R")



library(RODBC)  #To get data form Data Analysis DB
library(plyr)  #To manipulate data
library(reshape)  #More data manipulation
library(ggplot2)  #Graphics of grammer graphing
library(grid)  #More Graphing
library(gridExtra)  #better than par(mfrow=c(r,c)) for arranging ggplot2 and lattice graphics
library(randomNames)  #to do as it says and generate random names by gender and ethnicity.  Awesome!
```



### Loading Data into MySQL Database
We use two steps to get the data into the database:
  1. **Cleaning**: re-factoring the CDF's separate csv files so they comport with `MySQL` conventions. This is done with a "one touch" shell script that uses `sed` and regular expressions to make all necessary character substations. Theone-touch script for cleaning the data can be found [here](http://github.com/chrishaid/Data_Analysis/blob/master/MAP/Code/SQL/map_cdf_prep.sh);  
  2. **Loading**:putting the separate CSV files as separate tables into the data analysis database.  Doing so ensures that we maintain the data in as similar manner as we receive it from NWEA. The `SQL` code for loading the data is [here](github.com/chrishaid/Data_Analysis/blob/master/MAP/Code/SQL/Data_Loading_MAP.sql).
  
 

### Retrieving Data from MySQL Database
Once the data loaded, we use the `RODBC` package in `R` to establish a connection to the database and run a SQL query to populate a dataframe (NB: `kippchidata2` is a DSN with appropriate key value pairs that allows an `ODBC` connection to be established with the `MySQL' server).  To protect the privacy of our students while simultaneously showing you all my work flow, I've suppressed the evaluation of the following code.  That is, this next chunk of code is not run.


```r

# Create database connection.  

con<-odbcConnect("kippchidata2")

#get MAP data with SQL statement
map.scores<-sqlQuery(con, 
"SELECT  t.StudentID AS ID,
		t.`StudentFirstName`,
		t.`StudentLastName`,
		t.`SchoolName`,
		t.`Grade`,	
		t.`ClassName`,
		t.MeasurementScale AS Subject,
		t.GrowthMeasureYN AS Fall12_GM,
		t.TestType AS  Fall12_TT, 
		t.TestRITScore AS Fall12_RIT,
		t.TestPercentile AS Fall12_Pctl,
		n.t42 as TypicalFallToSpringGrowth,
		n.r42 as ReportedFallToSpringGrowth,
		n.s42 as SDFallToSpringGrowth,
		CASE
			WHEN TestPercentile >= 75 THEN 4
			WHEN TestPercentile < 75 AND TestPercentile>=50 THEN 3
			WHEN TestPercentile < 50 AND TestPercentile>=25 THEN 2
			ELSE 1
		END AS Quartile

FROM 	(
		SELECT 	a.*,
				c.ClassName
		FROM `tblClassAssignmentsFall12` as c
		JOIN (
			Select 	r.*, 
					s.DistrictName,
					s.`StudentDateOfBirth`,
					s.`StudentEthnicGroup`,
					s.`StudentLastName`,
					s.`StudentFirstName`,
					s.`StudentMI`,
					s.`Grade`
			FROM	tblAssessmentResultsFall12 as r
	    	JOIN	tblStudentBySchoolFall12 as s
			ON		r.`StudentID`=s.StudentID
			) as a
		ON a.StudentID=c.StudentID
		) as t
LEFT OUTER JOIN `viewNorms2011_Growth_Kinder_0` as n
ON 		t.`TestRITScore`=n.`StartRIT`
AND		t.`Grade`=n.`StartGrade2`
AND		t.`MeasurementScale`=n.`MeasurementScale`
WHERE 	#GrowthMeasureYN='True' AND
 	(TestType='Survey with Goals'
		OR 
		TestType='Survey'
		)
;

")

#Check contents
head(map.scores)

#Reorder levels (since 13=Kinder, prior to Fall 2012, after that it is Kinder=0) and rename
map.scores$Grade <- factor(map.scores$Grade, levels=c("0", "1","2", "5", "6","7","8"))
levels(map.scores$Grade) <- c("K", "1", "2", "5", "6","7","8")
```


### Masked Data!!!
Since I didn't run the data loading code that I do run for KIPP Chicago's own reporting, I need to generate some face data, which is pretty straightforward.  Mostly I need fake names to mask the identity of our students.  I'll pull actual test scores from the database so that we can use real targets and percentiles in the graphics to follow.


```r

# Create database connection.  
con<-odbcConnect("kippchidata2")
```

```
## Warning: [RODBC] ERROR: state HY000, code 2003, message [MySQL][ODBC 5.1
## Driver]Can't connect to MySQL server on '54.245.118.235' (60)
```

```
## Warning: ODBC connection failed
```

```r

#Pull data from db with SQL query
map.scores<-sqlQuery(con, 
"SELECT  t.`SchoolName`,
  	t.`Grade`,	
		t.`ClassName`,
		t.MeasurementScale AS Subject,
		t.GrowthMeasureYN AS Fall12_GM,
		t.TestType AS  Fall12_TT, 
		t.TestRITScore AS Fall12_RIT,
		t.TestPercentile AS Fall12_Pctl,
		n.t42 as TypicalFallToSpringGrowth,
		n.r42 as ReportedFallToSpringGrowth,
		n.s42 as SDFallToSpringGrowth,
		CASE
			WHEN TestPercentile >= 75 THEN 4
			WHEN TestPercentile < 75 AND TestPercentile>=50 THEN 3
			WHEN TestPercentile < 50 AND TestPercentile>=25 THEN 2
			ELSE 1
		END AS Quartile

FROM 	(
		SELECT 	a.*,
				c.ClassName
		FROM `tblClassAssignmentsFall12` as c
		JOIN (
			Select 	r.*, 
					s.DistrictName,
					s.`StudentDateOfBirth`,
					s.`StudentEthnicGroup`,
					s.`StudentLastName`,
					s.`StudentFirstName`,
					s.`StudentMI`,
					s.`Grade`
			FROM	tblAssessmentResultsFall12 as r
	    	JOIN	tblStudentBySchoolFall12 as s
			ON		r.`StudentID`=s.StudentID
			) as a
		ON a.StudentID=c.StudentID
		) as t
LEFT OUTER JOIN `viewNorms2011_Growth_Kinder_0` as n
ON 		t.`TestRITScore`=n.`StartRIT`
AND		t.`Grade`=n.`StartGrade2`
AND		t.`MeasurementScale`=n.`MeasurementScale`
WHERE GrowthMeasureYN='True' 
      AND
  	  (TestType='Survey with Goals'
		  OR 
		  TestType='Survey'
		  )
      AND t.MeasurementScale ='Mathematics'
      AND Grade=5
      AND SchoolName='KIPP Ascend Middle School'                   
;

")
```

```
## Error: first argument is not an open RODBC channel
```

```r

#need to add fake first and last names data using randomName package

#need set of ethnicities to draw form.  95% African American implies 19:1 odds.  Assume gender is 1:1.
ethnicities <- c(rep("African American",19), "Hispanic")
genders <- c("Female", "Male")

#now need to construct 2vectors (length = lenght(map.scores) drawn from the two sets above)

genderethnicity.df<-data.frame(Gender=sample(genders, nrow(map.scores), replace=TRUE), 
                               Ethnicity=sample(ethnicities, nrow(map.scores), replace=TRUE))
```

```
## Error: object 'map.scores' not found
```

```r

names.df<-data.frame(StudentLastName=randomNames(gender=genderethnicity.df$Gender,
                                                 ethnicity=genderethnicity.df$Ethnicity, which.names="last"),
                     StudentFirstName=randomNames(gender=genderethnicity.df$Gender,
                                                  ethnicity=genderethnicity.df$Ethnicity, which.names="first"
                                                  )
                     )
```

```
## Error: object 'genderethnicity.df' not found
```

```r

map.scores<-cbind(names.df, map.scores)
```

```
## Error: object 'names.df' not found
```

```r

head(map.scores)
```

```
## Error: object 'map.scores' not found
```


___

## Data Manipulation

### MAP Target Setting

The term "Growth Target" is misnomer.  The "growth target" is simply a students expected (or average) growth conditional on their starting RIT score and current grade.  That is, the period 1 to period 2  "growth target" is the average difference in period 1 and period 2 scores for all students in a particular grade with same period 1 score.  For this reason I refer to the the NWEA supplied "growth targets" as *expected growth* (a statistically meaningful term) or *typical growth* (a substantively meaningful term). As Andrew Martin at Team schools, among others, has made clear, if our students merely hit their expected growth numbers every year through 11th grade they will on average not be "Rutgers Ready" (Team's clever alliteration).

Time requires that I eschew Andrew's quadratic-fit goal-setting that they employ in Newark. Instead, I use the data we have from the 2011 MAP Norms Table to provide our teachers and students targets that at the 75th percentile of growth (i.e., the mean plus .675 standard deviations) for each Grade-Subject-Fall RIT score triplet. 


```r
# get z score (i.e., number of standard deviations) that corresponds to
# 75th percentile
sigma <- qnorm(0.75)
# add simga*SD to mean and round to integer
map.scores$GrowthPctl75th <- round(map.scores$TypicalFallToSpringGrowth + sigma * 
    map.scores$SDFallToSpringGrowth, 0)
```

```
## Error: object 'map.scores' not found
```

```r

# calculate targets
map.scores$GrowthTargets <- map.scores$Fall12_RIT + map.scores$GrowthPctl75th
```

```
## Error: object 'map.scores' not found
```

```r

# Combine Student First and Last Names into one field

map.scores$StudentLastFirstName <- paste(map.scores$StudentLastName, map.scores$StudentFirstName, 
    sep = ", ")
```

```
## Error: object 'map.scores' not found
```

```r
map.scores$StudentFirstLastName <- paste(map.scores$StudentFirstName, map.scores$StudentLastName, 
    sep = " ")
```

```
## Error: object 'map.scores' not found
```


___ 


##Visualizations

### MAP Results by Students with Targets, or How is each student doing relative to every other student in her class?
So now we move on to graphing, leaning heavily (completely?) on the [Hadley Wickham's `ggplot2`](http://www.http://ggplot2.org/) package.

In order to list students by order of test scores, I need a function to add a column that adds a counter after they are sorted on a given column's values.  Fortuitously, I've written this function---along with a number of other helper functions for this analysis---in an `R` script called (perhaps obviously) `MAP_helper_functions.R`, which is located in this directory of the GIT repo.

```r
source("MAP_helper_functions.R")
```

OK. Now to graphics.  Here I want to graph the fall score, the expected growth and the college ready 75th percentile growth.  Since we want graphs by grade we need to use `ddply` to run `fn_orderid` over each grade as well as each classroom for each subject:


```r
map.scores.by.grade <- ddply(map.scores, .(Subject, SchoolName, Grade), function(df) orderid(df, 
    df$Fall12_RIT))
```

```
## Error: object 'map.scores' not found
```

```r
map.scores.by.class <- ddply(map.scores, .(Subject, SchoolName, ClassName), 
    function(df) orderid(df, df$Fall12_RIT))
```

```
## Error: object 'map.scores' not found
```

```r

head(map.scores.by.grade)
```

```
## Error: object 'map.scores.by.grade' not found
```

```r
head(map.scores.by.class)
```

```
## Error: object 'map.scores.by.class' not found
```




```r

#KIPP Foundation approved colors
kippcols<-c("#E27425", "#FEBC11", "#255694", "A7CFEE")

#Plot points for Fall RIT Score, Expected Growth, College Ready Growth, ordered by Fall RIT, Names on Y axis
pointsize<-2
p <- ggplot(map.scores.by.grade, aes(x=Fall12_RIT, 
                                     y=OrderID)) +
     geom_text(aes(x=Fall12_RIT-1, 
                  color=as.factor(Quartile), 
                  label=StudentFirstLastName), 
              size=2, 
              hjust=1) +
    geom_point(aes(color=as.factor(Quartile)), 
               size=pointsize) +
    geom_text(aes(x=Fall12_RIT+1,
                  color=as.factor(Quartile), 
                  label=Fall12_RIT), 
              size=2, 
              hjust=0) +
    geom_point(aes(x=Fall12_RIT + ReportedFallToSpringGrowth, 
                   y=OrderID), 
               color="#CFCCC1", 
               size=pointsize) +
    geom_text(aes(x=Fall12_RIT + ReportedFallToSpringGrowth+1, 
                  label=Fall12_RIT + ReportedFallToSpringGrowth), 
              color="#CFCCC1", 
              size=2, 
              hjust=0) +
    geom_point(aes(x=GrowthTargets, 
                   y=OrderID), 
               color="#FEBC11", 
               size=pointsize) + 
    geom_text(aes(x=GrowthTargets+1, 
                  label=GrowthTargets), 
              color="#FEBC11", 
              size=2, 
              hjust=0) +
    facet_grid(Quartile~., scale="free_y", space = "free_y", as.table=FALSE) +
    scale_colour_discrete(kippcols) + 
    scale_y_continuous(" ", breaks=map.scores.by.grade$OrderID, expand=c(0,1)) + 
    theme(axis.text.y = element_text(size=3, hjust=1)) + 
    theme(legend.position = "none") + 
    scale_x_continuous("RIT Score") + 
    expand_limits(x=145)+
    theme(panel.background = element_rect(fill = "transparent",colour = NA), # or element_blank()
          plot.background = element_rect(fill = "transparent",colour = NA),
          
          axis.text.x = element_text(size=15),
          axis.text.y = element_blank(), 
          axis.ticks=element_blank(),
          
          strip.text.x=element_text(size=15),
          strip.text.y=element_text(size=15,angle=0), 
          strip.background=element_rect(fill="#F4EFEB", colour=NA),
        
          plot.title=element_text(size=12)
        ) +
        ggtitle("2012 Fall 5th Grade Mathematics\nRIT Scores, 
                Expected Growth, and College Ready Growth\nby Quartile")  
```

```
## Error: object 'map.scores.by.grade' not found
```

```r


###Let's add some summary labels by quaritle to p

#First get the per panel data I want count by quartile, avg y-position (given by OrderID) by quartile,
#  avg RIT by quartile, and percent of quartile students to total studens.

qrtl.labels<-get_group_stats(map.scores.by.grade, grp="Quartile")
```

```
## Error: object 'map.scores.by.grade' not found
```

```r

#add a column with the actual label text
qrtl.labels$CountLabel<-paste(qrtl.labels$CountStudents,
                              " students (",
                              round(qrtl.labels$PctofTotal*100),"%)", 
                              sep="")
```

```
## Error: object 'qrtl.labels' not found
```

```r

qrtl.labels$AvgLabel<-paste("Avg RIT = ",round(qrtl.labels$AvgQrtlRIT))
```

```
## Error: object 'qrtl.labels' not found
```

```r

#eyeballed X position
qrtl.labels$xpos<-rep(150,nrow(qrtl.labels))
```

```
## Error: object 'qrtl.labels' not found
```

```r

#now adding this info to the plot p
p <- p + geom_text(data=qrtl.labels, 
                   aes(x=xpos, 
                       y=AvgCountID, 
                       color=factor(Quartile),
                       label=CountLabel),
                   vjust=0, 
                   size=3.25) +
    geom_text(data=qrtl.labels, 
              aes(x=xpos, 
                  y=AvgCountID, 
                  color=factor(Quartile),
                  label=AvgLabel),
              vjust=1.5, 
              size=3.25)
```

```
## Error: object 'p' not found
```

```r

p
```

```
## Error: object 'p' not found
```

```r

#Uncomment below to save pdf vector file of plot for other uses. 
ggsave(p,file="plot_Goal_by_grade_KAPS_1.pdf",height=10.5,width=8)
```

```
## Error: object 'p' not found
```


I liked plot so much that I've written a function (`plot_MAP_Results_and_Goals`) so I can very quickly reproduce it for any grade and Class combination, which is sourced above in the [`MAP_helper_function.R`](https://github.com/chrishaid/Data_Analysis/blob/master/MAP/Code/R/MAP_helper_functions.R) script ($\leftarrow$ that's a clickable link to the code).  Right now it is only useful if the dataframe has very specific column names.  However, it is a stake in the ground that for a later re-factoring towards a more general function.  That notwithstanding time pressure, here's the current function in actions (**NB: This code isn't evaluated here; it is only an exmaple **)


```r
#Relevel subject factors 
map.scores.by.grade$Subject<-factor(map.scores.by.grade$Subject, 
                                    levels=c("Mathematics", 
                                             "Reading", 
                                             "Language Usage", 
                                             "General Science"))

map.scores.by.class$Subject<-factor(map.scores.by.grade$Subject, 
                                    levels=c("Mathematics", 
                                             "Reading", 
                                             "Language Usage", 
                                             "General Science"))

###Separate PDF for each School


#KAPS
#First by Grade
map.scores.primary<-subset(map.scores.by.grade, SchoolName=="KIPP Ascend Primary")

pdf(file="../../Figures/Fall12_MAP_KAPS.pdf", height=10.5, width=8)

for(s in sort(unique(map.scores.primary$Subject))){
  dfp<-subset(map.scores.primary,Subject==s) #DataFrame to Plot
  for(g in as.character(sort(unique(dfp$Grade)))){
    ptitle <- paste("KAPS 2012 Fall MAP Grade ",g," ",s,
                    "\nRIT Scores, Expected Growth, and College Ready Growth\nby Quartile",
                    sep="")
    p<-plot_MAP_Results_and_Goals(subset(dfp,Grade==g),ptitle, labxpos=113, minx=104)
    print(p)
  }
}
dev.off()

#Then by Classroom (KAPS only)

map.scores.primary.by.class<-subset(map.scores.by.class, SchoolName=="KIPP Ascend Primary" & ID!="50206087") 
# This kid is assinged to two classes in math as a 1st grader but the classes are K classees. Weird.

pdf(file="../../Figures/Fall12_MAP_KAPS_by_Classroom.pdf", height=10.5, width=8)
#Need to Loop by Subject, then grade, then classroom
for(s in as.character(sort(unique(map.scores.primary.by.class$Subject)))){
    dfs<-subset(map.scores.primary.by.class,Subject==s) #DataFrame for subject
    for(g in as.character(sort(unique(dfs$Grade)))){
      dfp<-subset(dfs, Grade==g)  #DataFrame for Plot
      for(c in as.character(sort(unique(dfp$ClassName)))){
        ptitle <- paste("KAPS 2012 Fall MAP ",c," (",g,") ",s,
                        "\nRIT Scores, Expected Growth, and College Ready Growth\nby Quartile",
                        sep="")
        p<-plot_MAP_Results_and_Goals(subset(dfp, ClassName==c),ptitle, labxpos=113, minx=104)
        print(p)
      }
    }
}
dev.off()



#KAMS
map.scores.KAMS<-subset(map.scores.by.grade, SchoolName=="KIPP Ascend Middle School")

pdf(file="../../Figures/Fall12_MAP_KAMS.pdf", height=10.5, width=8)

for(s in sort(unique(map.scores.KAMS$Subject))){
  dfp<-subset(map.scores.KAMS,Subject==s) #DataFrame to Plot
  for(g in as.character(sort(unique(dfp$Grade)))){
    ptitle <- paste("KAMS 2012 Fall MAP Grade ",g," ",s,
                    "\nRIT Scores, Expected Growth, and College Ready Growth\nby Quartile",
                    sep="")
    p<-plot_MAP_Results_and_Goals(subset(dfp,Grade==g),ptitle, labxpos=170, minx=145,alp=.6)
    print(p)
  }
}
dev.off()


#KCCP
map.scores.KCCP<-subset(map.scores.by.grade, SchoolName=="KIPP Create Middle School")

pdf(file="../../Figures/Fall12_MAP_KCCP.pdf", height=10.5, width=8)

for(s in sort(unique(map.scores.KCCP$Subject))){
  dfp<-subset(map.scores.KCCP,Subject==s) #DataFrame to Plot
  for(g in as.character(sort(unique(dfp$Grade)))){
    ptitle <- paste("KCCP 2012 Fall MAP Grade ",g," ",s,
                    "\nRIT Scores, Expected Growth, and College Ready Growth\nby Quartile",
                    sep="")
    p<-plot_MAP_Results_and_Goals(subset(dfp,Grade==g),ptitle, labxpos=150, minx=140, alp=.6)
    print(p)
  }
}
dev.off()

```



### Comparative Distrubionts (really histograms), or How are our student's doing relatively to the rest of their peers throughtout this great land of ours?

Now for some more high level views compared to the national distribution.  These figures are helpful in understanding where a whole grade or classroom is relative to nationally representative distribution.  However, we don't have such a distribution, so I simulated one using the nationally normed means and standard deviations for each subject-grade pair.  I assumed that the distributions were truncated Gaussian (i.e., normal) distributions and used some basic probability theory to construct the a sample distribution.  The code for this is in the `MAP_helper_fucntions.R` script in the `map_combined_histo_data()` function.  It's worth a look if you want to see how almost any distribution can be built up by starting with the $U\sim(0,1)$, i.e., the uniform distribution over the interval from 0 to 1.  The histograms themselves are generated with the `map_comparative_histograms()` function in the same file.  

```r
# get national summary statistics for Reading and Math, Grades K-2,5-8 for
# simulation
nwea.norms.fall <- data.frame(Grade = factor(c("K", "K", "1", "1", "2", "2", 
    "5", "5", "6", "6", "7", "7", "8", "8"), levels = c("K", "1", "2", "5", 
    "6", "7", "8")), Subject = factor(c("Mathematics", "Reading", "Mathematics", 
    "Reading", "Mathematics", "Reading", "Mathematics", "Reading", "Mathematics", 
    "Reading", "Mathematics", "Reading", "Mathematics", "Reading"), levels = c("Mathematics", 
    "Reading")), Mean = c(143.7, 142.5, 162.8, 160.3, 178.2, 175.9, 212.9, 209.8, 
    219.6, 212.3, 225.6, 216.3, 230.2, 219.3), SD = c(11.88, 10.71, 13.57, 12.76, 
    12.97, 15.44, 14.18, 14.21, 15.37, 14.39, 16.79, 14.23, 17.04, 14.86))





# KAMS

pm5 <- map_comparative_histograms(map_combined_histo_data(kippdata = map.scores.by.grade, 
    normsdata = nwea.norms.fall, grade = 5, subj = "Mathematics", schoolname = "KAMS"), 
    legendpos = "none", title = "MAP 2012 5th Grade\nKAMS vs. National\nMath")
```

```
## Error: object 'map.scores.by.grade' not found
```

```r

pm5
```

```
## Error: object 'pm5' not found
```



Again I welcome and encourage all feedback on this.   Free to email me at [chaid@kippchicago.org](mailto:chaid@kippchicago.org) with any feedback. I hope this is helpful.
