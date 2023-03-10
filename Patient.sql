create database Patient
go
use Patient
go

--Activate sa user
alter login sa with password = 'password'
alter login sa enable
go
--Enable Dedicated Administrative Connection (DAC)
sp_configure 'remote admin connections', 1
go
reconfigure with override
go

--create user Niels with admin permissions
if not exists(select * from sys.server_principals where name = 'Niels')
begin
	create login Niels with password = 'password';
	create user Niels for login Niels;
	exec sp_addsrvrolemember 'Niels', 'sysadmin';
	alter login Niels with password = 'password';
	alter login Niels enable;
end
--Create user Ole with read permissions
if not exists (select * from sys.server_principals where name = 'Ole')
begin
    create login Ole with password = 'password';
    create user Ole for login Ole;
    use Patient;
    exec sp_addrolemember 'db_datareader','Ole';
    alter login Ole with password = 'password';
    alter login Ole enable;
end

create table Speciality
(
	Id int primary key identity(1,1),
	[Name] nvarchar(100) unique
);

create table Doctor
(
	Id int primary key identity(1,1),
	[Name] nvarchar(100) unique,
	SpecialeId int foreign key references Speciality(Id)
);

create table Patient
(
	Id int primary key identity(1,1),
	FirstName nvarchar(100),
	LastName nvarchar(100),
	PhoneNumber nvarchar(100) unique,
	ResponsibleDoctor int foreign key references Doctor(Id),
	constraint unique_patient_name unique (FirstName, LastName)
);

create table Patient_Doctor
(
	PatientId int,
	DoctorId int,
	primary key (PatientId, DoctorId),
	foreign key (PatientId) references Patient(Id),
	foreign key (DoctorId) references Doctor(Id)
);

create nonclustered index speciality_name on Speciality([Name]);
create nonclustered index doctor_name on Doctor([Name]);
create nonclustered index patient_firstName on Patient(FirstName);
create nonclustered index patient_lastName on Patient(LastName);



insert into Speciality([Name])values ('Radiologi')
insert into Speciality([Name])values ('Kirurgi')
insert into Speciality([Name])values ('Øjenlæge')

insert into Doctor([Name], SpecialeId) values ('Peter Hansen', 3)
insert into Doctor([Name], SpecialeId) values ('Martin Jensen', 1)
insert into Doctor([Name], SpecialeId) values ('Thomas Olsen', 2)

insert into Patient(FirstName, LastName, PhoneNumber, ResponsibleDoctor) values ('Andreas', 'Ulriksen', '50202102',2)
insert into Patient(FirstName, LastName, PhoneNumber, ResponsibleDoctor) values ('Bjørn', 'Sørensen', '50320212',3)
insert into Patient(FirstName, LastName, PhoneNumber, ResponsibleDoctor) values ('Christian', 'Michealsen', '50320145',2)

-- Add relationships between patients and doctors
insert into Patient_Doctor (PatientId, DoctorId) values (1,2);
insert into Patient_Doctor (PatientId, DoctorId) values (2,3);
insert into Patient_Doctor (PatientId, DoctorId) values (3,2);
insert into Patient_Doctor (PatientId, DoctorId) values (3,3);
insert into Patient_Doctor (PatientId, DoctorId) values (1,1);
go

-- Query to select all patients and their doctors
select Patient.FirstName, Patient.LastName, Doctor.[Name], Speciality.[Name] as Speciality
from Patient
inner join Patient_Doctor on Patient.Id = Patient_Doctor.PatientId
inner join Doctor on Patient_Doctor.DoctorId = Doctor.Id
inner join Speciality on Doctor.SpecialeId = Speciality.Id
order by Patient.LastName, Patient.FirstName;
go

--select all the patients and the number of doctors that they are assigned to
select Patient.Id, Patient.FirstName, Patient.LastName, COUNT(Patient_Doctor.DoctorId) as NumDoctors
from Patient
left join Patient_Doctor on Patient.Id = Patient_Doctor.PatientId
group by Patient.Id, Patient.FirstName, Patient.LastName;
go

--select all the doctors and the number of patients that they have assigned to
select Doctor.Id, Doctor.[Name], COUNT(Patient_Doctor.PatientId) as NumPatients
from Doctor
left join Patient_Doctor on Doctor.Id = Patient_Doctor.DoctorId
group by Doctor.Id, Doctor.[Name];
go

alter table Patient
add Age int;
go

update Patient
set Age = 35
where FirstName = 'Andreas' and LastName = 'Ulriksen';

update Patient
set Age = 40
where FirstName = 'Bjørn' and LastName = 'Sørensen';

update Patient
set Age = 47
where FirstName = 'Christian' and LastName = 'Michealsen';
go

select AVG(Age) as avg_age from Patient;

go

--Lav en backup/restoretest af patient databasen:
use master
go

declare @patientDatabase_backup_file nvarchar(100)
set @patientDatabase_backup_file = 'C:\Backup\patient_database_fullbackup_' + REPLACE(CONVERT(varchar, GETDATE(), 120), ':', '-') + '.bak'

backup database Patient
to disk = @patientDatabase_backup_file
with format, init, skip, stats = 10, compression;

--delete database
drop database Patient

--restore database
restore database Patient from disk= @patientDatabase_backup_file with replace
go
use Patient
go

--Opret storedproceduresom kan anvendes til indtaste test patienter mod det oprettet database:
create trigger check_doctor_patient_count
on patient
after insert
as
begin
	if (select count(*) from Patient where ResponsibleDoctor = (select ResponsibleDoctor from inserted)) > 3
	begin
		raiserror ('Denne læge har allerede 3 eller flere patienter tildelt.', 16, 1)
		rollback transaction
	end
end


--fjern kommentarer af denne kode ned, hvis du er villig til at køre den mere end en gang

--go
--use master
--go
--drop database Patient